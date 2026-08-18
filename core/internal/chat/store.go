package chat

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	_ "modernc.org/sqlite"
)

// One database for every provider, keyed on (provider, chat_id, id) throughout.
// A single store rather than one per provider is what makes the cross-provider
// chat list -- and Super+Tab across services -- a query rather than a merge.
const historySchema = `
CREATE TABLE IF NOT EXISTS chats (
  provider     TEXT NOT NULL,
  id           TEXT NOT NULL,
  name         TEXT NOT NULL DEFAULT '',
  is_group     INTEGER NOT NULL DEFAULT 0,
  last_ts      INTEGER NOT NULL DEFAULT 0,
  last_text    TEXT NOT NULL DEFAULT '',
  unread       INTEGER NOT NULL DEFAULT 0,
  muted        INTEGER NOT NULL DEFAULT 0,
  archived     INTEGER NOT NULL DEFAULT 0,
  read_upto    INTEGER NOT NULL DEFAULT 0,
  avatar_path  TEXT NOT NULL DEFAULT '',
  subject      TEXT NOT NULL DEFAULT '',
  participants TEXT NOT NULL DEFAULT '',
  folder       TEXT NOT NULL DEFAULT '',
  handles      TEXT NOT NULL DEFAULT '',
  tags         TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (provider, id)
);

CREATE TABLE IF NOT EXISTS messages (
  provider    TEXT NOT NULL,
  chat_id     TEXT NOT NULL,
  id          TEXT NOT NULL,
  ts          INTEGER NOT NULL,
  from_me     INTEGER NOT NULL DEFAULT 0,
  sender_id   TEXT NOT NULL DEFAULT '',
  sender_name TEXT NOT NULL DEFAULT '',
  sender_avatar_path TEXT NOT NULL DEFAULT '',
  kind        TEXT NOT NULL DEFAULT 'text',
  text        TEXT NOT NULL DEFAULT '',
  body_html   TEXT NOT NULL DEFAULT '',
  status      TEXT NOT NULL DEFAULT 'sent',
  reply_to    TEXT NOT NULL DEFAULT '',
  link_url    TEXT NOT NULL DEFAULT '',
  link_title  TEXT NOT NULL DEFAULT '',
  link_desc   TEXT NOT NULL DEFAULT '',
  link_image  TEXT NOT NULL DEFAULT '',
  cc          TEXT NOT NULL DEFAULT '',
  bcc         TEXT NOT NULL DEFAULT '',
  media_path  TEXT NOT NULL DEFAULT '',
  media_ref   TEXT NOT NULL DEFAULT '',
  media_mime  TEXT NOT NULL DEFAULT '',
  media_w     INTEGER NOT NULL DEFAULT 0,
  media_h     INTEGER NOT NULL DEFAULT 0,
  file_name   TEXT NOT NULL DEFAULT '',
  file_size   INTEGER NOT NULL DEFAULT 0,
  duration    INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (provider, chat_id, id)
);

CREATE INDEX IF NOT EXISTS idx_msg_chat_ts ON messages(provider, chat_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_msg_id      ON messages(provider, id);

-- Volatile per-provider state (sync cursors, last open chat) belongs here and
-- not in the shell's settings.json: it changes far too often to be worth
-- round-tripping through a user-editable config file.
CREATE TABLE IF NOT EXISTS meta (
  provider TEXT NOT NULL,
  k        TEXT NOT NULL,
  v        TEXT NOT NULL,
  PRIMARY KEY (provider, k)
);
`

// FTS5 is optional: modernc.org/sqlite ships it, but a database that predates
// this table, or a build without the module, must still work. Search degrades
// to LIKE when ftsReady is false.
const ftsSchema = `
CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
  text,
  content='messages',
  content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS messages_fts_ai AFTER INSERT ON messages BEGIN
  INSERT INTO messages_fts(rowid, text) VALUES (new.rowid, new.text);
END;
CREATE TRIGGER IF NOT EXISTS messages_fts_ad AFTER DELETE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, text) VALUES('delete', old.rowid, old.text);
END;
CREATE TRIGGER IF NOT EXISTS messages_fts_au AFTER UPDATE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, text) VALUES('delete', old.rowid, old.text);
  INSERT INTO messages_fts(rowid, text) VALUES (new.rowid, new.text);
END;
`

// migrations are applied unconditionally on open; "duplicate column" is the
// expected outcome on an already-current database and is swallowed. Additive
// only -- never drop or rename, since an older dms may still open this file.
var migrations = []string{
	`ALTER TABLE messages ADD COLUMN sender_avatar_path TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE chats ADD COLUMN handles TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE chats ADD COLUMN tags TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE messages ADD COLUMN link_url TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE messages ADD COLUMN link_title TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE messages ADD COLUMN link_desc TEXT NOT NULL DEFAULT ''`,
	`ALTER TABLE messages ADD COLUMN link_image TEXT NOT NULL DEFAULT ''`,
}

// HistoryStore is the message store. Safe for concurrent use.
type HistoryStore struct {
	db       *sql.DB
	ftsReady bool
}

// OpenHistory opens (creating if needed) the message store at path.
func OpenHistory(path string) (*HistoryStore, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, fmt.Errorf("create history dir: %w", err)
	}

	db, err := sql.Open("sqlite", path+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(on)")
	if err != nil {
		return nil, fmt.Errorf("open history db: %w", err)
	}

	// One writer. The host process is the only thing that touches this file,
	// and serialising here is cheaper than contending on SQLITE_BUSY.
	db.SetMaxOpenConns(1)

	if _, err := db.Exec(historySchema); err != nil {
		db.Close()
		return nil, fmt.Errorf("init history schema: %w", err)
	}

	for _, stmt := range migrations {
		if _, err := db.Exec(stmt); err != nil && !strings.Contains(err.Error(), "duplicate column") {
			db.Close()
			return nil, fmt.Errorf("migrate history db: %w", err)
		}
	}

	s := &HistoryStore{db: db}
	if _, err := db.Exec(ftsSchema); err == nil {
		s.ftsReady = true
	}

	// The database may hold message contents; SQLite creates its files 0644.
	_ = os.Chmod(path, 0o600)
	for _, suffix := range []string{"-wal", "-shm"} {
		_ = os.Chmod(path+suffix, 0o600)
	}

	return s, nil
}

func (s *HistoryStore) Close() error { return s.db.Close() }

// ---------------------------------------------------------------- chats

// UpsertChat merges a chat, leaving fields the caller left blank untouched.
//
// Bridges routinely send partial chats -- a name-only update, a handles-only
// backfill -- so a blind overwrite would erase whatever the previous event
// knew. Archived and muted are not settable here at all; see the note in the
// conflict clause.
func (s *HistoryStore) UpsertChat(ctx context.Context, c Chat) error {
	participants, _ := json.Marshal(c.Participants)
	if c.Participants == nil {
		participants = []byte("")
	}
	handles, _ := json.Marshal(c.Handles)
	if c.Handles == nil {
		handles = []byte("")
	}
	tags, _ := json.Marshal(c.Tags)
	if c.Tags == nil {
		tags = []byte("")
	}

	_, err := s.db.ExecContext(ctx, `
INSERT INTO chats (provider, id, name, is_group, last_ts, last_text, unread, muted, archived,
                   read_upto, avatar_path, subject, participants, folder, handles, tags)
VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
ON CONFLICT(provider, id) DO UPDATE SET
  name         = CASE WHEN excluded.name         != '' THEN excluded.name         ELSE chats.name         END,
  is_group     = excluded.is_group OR chats.is_group,
  last_ts      = MAX(excluded.last_ts, chats.last_ts),
  last_text    = CASE WHEN excluded.last_ts >= chats.last_ts AND excluded.last_text != ''
                      THEN excluded.last_text ELSE chats.last_text END,
  unread       = CASE WHEN excluded.unread >= 0 THEN excluded.unread ELSE chats.unread END,
  -- muted and archived are deliberately absent: a Go bool cannot say "unset",
  -- so an upsert carrying only a name would silently unarchive the chat. They
  -- change through SetArchived and SetMuted, which are only called when a
  -- bridge actually said so.
  read_upto    = MAX(excluded.read_upto, chats.read_upto),
  avatar_path  = CASE WHEN excluded.avatar_path  != '' THEN excluded.avatar_path  ELSE chats.avatar_path  END,
  subject      = CASE WHEN excluded.subject      != '' THEN excluded.subject      ELSE chats.subject      END,
  participants = CASE WHEN excluded.participants != '' THEN excluded.participants ELSE chats.participants END,
  folder       = CASE WHEN excluded.folder       != '' THEN excluded.folder       ELSE chats.folder       END,
  handles      = CASE WHEN excluded.handles      != '' THEN excluded.handles      ELSE chats.handles      END,
  tags         = CASE WHEN excluded.tags         != '' THEN excluded.tags         ELSE chats.tags         END
`,
		c.Provider, c.ID, c.Name, c.IsGroup, c.LastTS, c.LastText, c.Unread, c.Muted, c.Archived,
		c.ReadUpTo, c.AvatarPath, c.Subject, string(participants), c.Folder, string(handles), string(tags))
	return err
}

// TouchChat updates a chat's activity line from a message that just landed,
// creating the chat if a bridge sent a message for one we have never seen.
func (s *HistoryStore) TouchChat(ctx context.Context, provider, chatID, name, lastText string, ts int64, isGroup, incrementUnread bool) error {
	unread := 0
	if incrementUnread {
		unread = 1
	}

	_, err := s.db.ExecContext(ctx, `
INSERT INTO chats (provider, id, name, is_group, last_ts, last_text, unread)
VALUES (?,?,?,?,?,?,?)
ON CONFLICT(provider, id) DO UPDATE SET
  name      = CASE WHEN excluded.name != '' THEN excluded.name ELSE chats.name END,
  is_group  = excluded.is_group OR chats.is_group,
  last_ts   = MAX(excluded.last_ts, chats.last_ts),
  last_text = CASE WHEN excluded.last_ts >= chats.last_ts THEN excluded.last_text ELSE chats.last_text END,
  unread    = chats.unread + excluded.unread
`, provider, chatID, name, isGroup, ts, lastText, unread)
	return err
}

const chatSelect = `
SELECT c.provider, c.id, c.name, c.is_group, c.last_ts, c.last_text, c.unread, c.muted,
       c.archived, c.read_upto, c.avatar_path, c.subject, c.participants, c.folder, c.handles, c.tags,
       COALESCE((SELECT MAX(m.ts) FROM messages m
                  WHERE m.provider = c.provider AND m.chat_id = c.id
                    AND m.from_me = 1
                    AND m.kind NOT IN ('system','deleted','unsupported')), 0) AS my_last_ts
FROM chats c
`

// Chats returns conversations across every provider, most recent first.
//
// my_last_ts deliberately excludes protocol kinds: history sync marks those as
// yours, and counting them would report that you take part in every channel you
// have ever been added to.
func (s *HistoryStore) Chats(ctx context.Context, limit int) ([]Chat, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := s.db.QueryContext(ctx, chatSelect+`
WHERE c.last_ts > 0
ORDER BY c.last_ts DESC
LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanChats(rows)
}

// AllChats returns every known conversation, including ones with no messages
// yet.
//
// Distinct from Chats: a provider's history sync announces conversations before
// any message arrives, so most of what it knows has no timestamp. Those belong
// in search and in a chat picker -- you should be able to find someone you have
// never written to -- but not in the conversation list, which would otherwise
// be mostly address book.
func (s *HistoryStore) AllChats(ctx context.Context, limit int) ([]Chat, error) {
	if limit <= 0 {
		limit = 5000
	}
	rows, err := s.db.QueryContext(ctx, chatSelect+`
ORDER BY c.last_ts DESC, c.name ASC
LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanChats(rows)
}

// ChatsForProvider is Chats scoped to one provider.
func (s *HistoryStore) ChatsForProvider(ctx context.Context, provider string, limit int) ([]Chat, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := s.db.QueryContext(ctx, chatSelect+`
WHERE c.provider = ? AND c.last_ts > 0
ORDER BY c.last_ts DESC
LIMIT ?`, provider, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanChats(rows)
}

// ChatByID returns one chat, or sql.ErrNoRows.
func (s *HistoryStore) ChatByID(ctx context.Context, provider, chatID string) (Chat, error) {
	rows, err := s.db.QueryContext(ctx, chatSelect+`WHERE c.provider = ? AND c.id = ?`, provider, chatID)
	if err != nil {
		return Chat{}, err
	}
	defer rows.Close()

	chats, err := scanChats(rows)
	if err != nil {
		return Chat{}, err
	}
	if len(chats) == 0 {
		return Chat{}, sql.ErrNoRows
	}
	return chats[0], nil
}

func scanChats(rows *sql.Rows) ([]Chat, error) {
	var out []Chat
	for rows.Next() {
		var c Chat
		var participants, handles, tags string
		if err := rows.Scan(&c.Provider, &c.ID, &c.Name, &c.IsGroup, &c.LastTS, &c.LastText,
			&c.Unread, &c.Muted, &c.Archived, &c.ReadUpTo, &c.AvatarPath, &c.Subject,
			&participants, &c.Folder, &handles, &tags, &c.MyLastTS); err != nil {
			return nil, err
		}
		if participants != "" {
			_ = json.Unmarshal([]byte(participants), &c.Participants)
		}
		if handles != "" {
			_ = json.Unmarshal([]byte(handles), &c.Handles)
		}
		if tags != "" {
			_ = json.Unmarshal([]byte(tags), &c.Tags)
		}
		c.Tags = withDerivedTags(c)
		out = append(out, c)
	}
	return out, rows.Err()
}

// SetArchived hides or restores a chat. Archiving is how a user says "keep this
// out of my way", so archived chats never notify and never enter the rotation.
func (s *HistoryStore) SetArchived(ctx context.Context, provider, chatID string, archived bool) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE chats SET archived = ? WHERE provider = ? AND id = ?`, archived, provider, chatID)
	return err
}

func (s *HistoryStore) SetMuted(ctx context.Context, provider, chatID string, muted bool) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE chats SET muted = ? WHERE provider = ? AND id = ?`, muted, provider, chatID)
	return err
}

// IsMuted reports the mute flag; a chat we do not know is not muted.
func (s *HistoryStore) IsMuted(ctx context.Context, provider, chatID string) bool {
	var muted bool
	err := s.db.QueryRowContext(ctx,
		`SELECT muted FROM chats WHERE provider = ? AND id = ?`, provider, chatID).Scan(&muted)
	return err == nil && muted
}

// IsArchived reports the archive flag.
func (s *HistoryStore) IsArchived(ctx context.Context, provider, chatID string) bool {
	var archived bool
	err := s.db.QueryRowContext(ctx,
		`SELECT archived FROM chats WHERE provider = ? AND id = ?`, provider, chatID).Scan(&archived)
	return err == nil && archived
}

// SetReadUpTo marks everything at or before ts as read and recomputes the
// unread count from the messages themselves.
//
// Recomputing rather than zeroing keeps the badge honest when a message arrives
// in the same instant the user opens the chat.
func (s *HistoryStore) SetReadUpTo(ctx context.Context, provider, chatID string, ts int64) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx,
		`UPDATE chats SET read_upto = MAX(read_upto, ?) WHERE provider = ? AND id = ?`,
		ts, provider, chatID); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, `
UPDATE chats SET unread = (
  SELECT COUNT(*) FROM messages m
   WHERE m.provider = chats.provider AND m.chat_id = chats.id
     AND m.from_me = 0 AND m.ts > chats.read_upto
     AND m.kind NOT IN ('system','deleted','unsupported')
) WHERE provider = ? AND id = ?`, provider, chatID); err != nil {
		return err
	}

	return tx.Commit()
}

// ---------------------------------------------------------------- messages

const messageUpsert = `
INSERT INTO messages (provider, chat_id, id, ts, from_me, sender_id, sender_name, sender_avatar_path,
                      kind, text, body_html, status, reply_to, cc, bcc, media_path, media_ref,
                      media_mime, media_w, media_h, file_name, file_size, duration,
                      link_url, link_title, link_desc, link_image)
VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
ON CONFLICT(provider, chat_id, id) DO UPDATE SET
  text        = CASE WHEN excluded.text != '' THEN excluded.text ELSE messages.text END,
  body_html   = CASE WHEN excluded.body_html != '' THEN excluded.body_html ELSE messages.body_html END,
  kind        = excluded.kind,
  sender_name = CASE WHEN excluded.sender_name != '' THEN excluded.sender_name ELSE messages.sender_name END,
  sender_avatar_path = CASE WHEN excluded.sender_avatar_path != '' THEN excluded.sender_avatar_path ELSE messages.sender_avatar_path END,
  -- Status only ratchets forward. A redelivered copy of an old message must not
  -- un-read something the user has already seen.
  status      = CASE WHEN ? > ? THEN excluded.status ELSE messages.status END,
  reply_to    = CASE WHEN excluded.reply_to != '' THEN excluded.reply_to ELSE messages.reply_to END,
  -- Keep media we already fetched if the redelivery arrives without it.
  media_path  = CASE WHEN excluded.media_path != '' THEN excluded.media_path ELSE messages.media_path END,
  media_ref   = CASE WHEN excluded.media_ref  != '' THEN excluded.media_ref  ELSE messages.media_ref  END,
  media_mime  = CASE WHEN excluded.media_mime != '' THEN excluded.media_mime ELSE messages.media_mime END,
  media_w     = CASE WHEN excluded.media_w > 0 THEN excluded.media_w ELSE messages.media_w END,
  media_h     = CASE WHEN excluded.media_h > 0 THEN excluded.media_h ELSE messages.media_h END,
  file_name   = CASE WHEN excluded.file_name != '' THEN excluded.file_name ELSE messages.file_name END,
  file_size   = CASE WHEN excluded.file_size > 0 THEN excluded.file_size ELSE messages.file_size END,
  duration    = CASE WHEN excluded.duration  > 0 THEN excluded.duration  ELSE messages.duration  END,
  link_url    = CASE WHEN excluded.link_url   != '' THEN excluded.link_url   ELSE messages.link_url   END,
  link_title  = CASE WHEN excluded.link_title != '' THEN excluded.link_title ELSE messages.link_title END,
  link_desc   = CASE WHEN excluded.link_desc  != '' THEN excluded.link_desc  ELSE messages.link_desc  END,
  link_image  = CASE WHEN excluded.link_image != '' THEN excluded.link_image ELSE messages.link_image END
`

func (s *HistoryStore) putMessage(ctx context.Context, tx *sql.Tx, m Message) error {
	if m.Kind == "" {
		m.Kind = KindText
	}
	if m.Status == "" {
		m.Status = StatusSent
	}

	cc, _ := json.Marshal(m.CC)
	bcc, _ := json.Marshal(m.BCC)
	if m.CC == nil {
		cc = []byte("")
	}
	if m.BCC == nil {
		bcc = []byte("")
	}

	// The two trailing binds drive the status ratchet in the ON CONFLICT arm.
	// They are computed here rather than in SQL because the rank ordering is a
	// Go-side concept and belongs next to statusRank.
	var existing string
	_ = tx.QueryRowContext(ctx, `SELECT status FROM messages WHERE provider = ? AND chat_id = ? AND id = ?`,
		m.Provider, m.ChatID, m.ID).Scan(&existing)

	_, err := tx.ExecContext(ctx, messageUpsert,
		m.Provider, m.ChatID, m.ID, m.TS, m.FromMe, m.SenderID, m.SenderName, m.SenderAvatarPath, m.Kind, m.Text,
		m.BodyHTML, m.Status, m.ReplyTo, string(cc), string(bcc), m.MediaPath, m.MediaRef,
		m.MediaMime, m.MediaW, m.MediaH, m.FileName, m.FileSize, m.Duration,
		m.LinkURL, m.LinkTitle, m.LinkDesc, m.LinkImage,
		statusRank(m.Status), statusRank(existing))
	return err
}

// PutMessage stores or merges one message.
func (s *HistoryStore) PutMessage(ctx context.Context, m Message) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.putMessage(ctx, tx, m); err != nil {
		return err
	}
	return tx.Commit()
}

// PutMessages stores a batch in one transaction.
//
// History sync arrives in thousands; one transaction per message turns a
// first login into minutes of fsync.
func (s *HistoryStore) PutMessages(ctx context.Context, msgs []Message) error {
	if len(msgs) == 0 {
		return nil
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, m := range msgs {
		if err := s.putMessage(ctx, tx, m); err != nil {
			return err
		}
	}
	return tx.Commit()
}

const messageSelect = `
SELECT provider, chat_id, id, ts, from_me, sender_id, sender_name, sender_avatar_path, kind, text,
       body_html, status, reply_to, cc, bcc, media_path, media_ref, media_mime, media_w, media_h,
       file_name, file_size, duration, link_url, link_title, link_desc, link_image
FROM messages
`

// Page returns up to limit messages in a chat older than before, oldest first.
//
// Keyset, never OFFSET: a chat can hold hundreds of thousands of rows, and
// OFFSET makes each scroll step slower than the last. Pass before = 0 for the
// newest page. hasMore is true when at least one older message remains.
func (s *HistoryStore) Page(ctx context.Context, provider, chatID string, before int64, limit int) (msgs []Message, hasMore bool, err error) {
	if limit <= 0 {
		limit = 50
	}
	if before <= 0 {
		before = 1<<63 - 1
	}

	// One extra row answers "is there more" without a second COUNT query.
	rows, err := s.db.QueryContext(ctx, messageSelect+`
WHERE provider = ? AND chat_id = ? AND ts < ?
ORDER BY ts DESC
LIMIT ?`, provider, chatID, before, limit+1)
	if err != nil {
		return nil, false, err
	}
	defer rows.Close()

	msgs, err = scanMessages(rows)
	if err != nil {
		return nil, false, err
	}

	if len(msgs) > limit {
		hasMore = true
		msgs = msgs[:limit]
	}

	// Queried newest-first for the index; the UI wants chronological.
	for i, j := 0, len(msgs)-1; i < j; i, j = i+1, j-1 {
		msgs[i], msgs[j] = msgs[j], msgs[i]
	}
	return msgs, hasMore, nil
}

// MessageByID returns one message, or sql.ErrNoRows.
func (s *HistoryStore) MessageByID(ctx context.Context, provider, chatID, id string) (Message, error) {
	rows, err := s.db.QueryContext(ctx, messageSelect+`
WHERE provider = ? AND chat_id = ? AND id = ?`, provider, chatID, id)
	if err != nil {
		return Message{}, err
	}
	defer rows.Close()

	msgs, err := scanMessages(rows)
	if err != nil {
		return Message{}, err
	}
	if len(msgs) == 0 {
		return Message{}, sql.ErrNoRows
	}
	return msgs[0], nil
}

func scanMessages(rows *sql.Rows) ([]Message, error) {
	var out []Message
	for rows.Next() {
		var m Message
		var cc, bcc string
		if err := rows.Scan(&m.Provider, &m.ChatID, &m.ID, &m.TS, &m.FromMe, &m.SenderID,
			&m.SenderName, &m.SenderAvatarPath, &m.Kind, &m.Text, &m.BodyHTML, &m.Status, &m.ReplyTo, &cc, &bcc,
			&m.MediaPath, &m.MediaRef, &m.MediaMime, &m.MediaW, &m.MediaH,
			&m.FileName, &m.FileSize, &m.Duration,
			&m.LinkURL, &m.LinkTitle, &m.LinkDesc, &m.LinkImage); err != nil {
			return nil, err
		}
		if cc != "" {
			_ = json.Unmarshal([]byte(cc), &m.CC)
		}
		if bcc != "" {
			_ = json.Unmarshal([]byte(bcc), &m.BCC)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// SetMessageStatus advances a message's delivery status.
//
// Matched on id alone within a provider, because several services report
// receipts against a different chat identifier than the one the message was
// delivered under.
func (s *HistoryStore) SetMessageStatus(ctx context.Context, provider, id, status string) error {
	_, err := s.db.ExecContext(ctx, `
UPDATE messages SET status = ?
 WHERE provider = ? AND id = ?
   AND ? > CASE status
             WHEN 'pending' THEN 1 WHEN 'failed' THEN 2 WHEN 'sent' THEN 3
             WHEN 'delivered' THEN 4 WHEN 'read' THEN 5 ELSE 0 END
`, status, provider, id, statusRank(status))
	return err
}

// MarkDeleted turns a message into a tombstone. The row survives so the
// conversation keeps its shape and reply targets still resolve.
func (s *HistoryStore) MarkDeleted(ctx context.Context, provider, chatID, id string) error {
	_, err := s.db.ExecContext(ctx, `
UPDATE messages SET kind = ?, text = '', body_html = '', media_path = '', media_ref = ''
 WHERE provider = ? AND chat_id = ? AND id = ?`, KindDeleted, provider, chatID, id)
	return err
}

// DeleteMessage removes a message outright.
//
// Distinct from MarkDeleted: this is for rows that should never have existed,
// such as the placeholder written while a send is in flight. A message deleted
// by its sender keeps its row and becomes a tombstone instead.
func (s *HistoryStore) DeleteMessage(ctx context.Context, provider, chatID, id string) error {
	_, err := s.db.ExecContext(ctx,
		`DELETE FROM messages WHERE provider = ? AND chat_id = ? AND id = ?`, provider, chatID, id)
	return err
}

// MediaRefFor returns the deferred-fetch handle for a message, if it has one.
func (s *HistoryStore) MediaRefFor(ctx context.Context, provider, chatID, id string) (string, error) {
	var ref string
	err := s.db.QueryRowContext(ctx,
		`SELECT media_ref FROM messages WHERE provider = ? AND chat_id = ? AND id = ?`,
		provider, chatID, id).Scan(&ref)
	return ref, err
}

// SetMediaPath records where a fetched attachment landed.
func (s *HistoryStore) SetMediaPath(ctx context.Context, provider, chatID, id, path string) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE messages SET media_path = ? WHERE provider = ? AND chat_id = ? AND id = ?`,
		path, provider, chatID, id)
	return err
}

// ---------------------------------------------------------------- search

// SearchMessages finds messages by body text, newest first.
//
// Uses FTS5 where available and falls back to LIKE otherwise, so search still
// works on a database created before the index existed.
func (s *HistoryStore) SearchMessages(ctx context.Context, query string, limit int) ([]SearchHit, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, nil
	}
	if limit <= 0 {
		limit = 50
	}

	var rows *sql.Rows
	var err error

	if s.ftsReady {
		// Quoted as a single FTS phrase: user input is not FTS syntax, and an
		// unbalanced quote or a bare NEAR would otherwise be a query error.
		phrase := `"` + strings.ReplaceAll(query, `"`, `""`) + `"`
		rows, err = s.db.QueryContext(ctx, `
SELECT m.provider, m.chat_id, m.id, m.ts, m.from_me, m.sender_id, m.sender_name,
       m.sender_avatar_path, m.kind, m.text, m.body_html, m.status, m.reply_to, m.cc, m.bcc,
       m.media_path, m.media_ref, m.media_mime, m.media_w, m.media_h, m.file_name, m.file_size,
       m.duration, m.link_url, m.link_title, m.link_desc, m.link_image,
       COALESCE(c.name, '')
  FROM messages_fts f
  JOIN messages m ON m.rowid = f.rowid
  LEFT JOIN chats c ON c.provider = m.provider AND c.id = m.chat_id
 WHERE messages_fts MATCH ?
 ORDER BY m.ts DESC
 LIMIT ?`, phrase, limit)
	} else {
		rows, err = s.db.QueryContext(ctx, `
SELECT m.provider, m.chat_id, m.id, m.ts, m.from_me, m.sender_id, m.sender_name,
       m.sender_avatar_path, m.kind, m.text, m.body_html, m.status, m.reply_to, m.cc, m.bcc,
       m.media_path, m.media_ref, m.media_mime, m.media_w, m.media_h, m.file_name, m.file_size,
       m.duration, m.link_url, m.link_title, m.link_desc, m.link_image,
       COALESCE(c.name, '')
  FROM messages m
  LEFT JOIN chats c ON c.provider = m.provider AND c.id = m.chat_id
 WHERE m.text LIKE '%' || ? || '%' ESCAPE '\'
 ORDER BY m.ts DESC
 LIMIT ?`, escapeLike(query), limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []SearchHit
	for rows.Next() {
		var h SearchHit
		var cc, bcc string
		if err := rows.Scan(&h.Provider, &h.ChatID, &h.ID, &h.TS, &h.FromMe, &h.SenderID,
			&h.SenderName, &h.SenderAvatarPath, &h.Kind, &h.Text, &h.BodyHTML, &h.Status, &h.ReplyTo, &cc, &bcc,
			&h.MediaPath, &h.MediaRef, &h.MediaMime, &h.MediaW, &h.MediaH,
			&h.FileName, &h.FileSize, &h.Duration,
			&h.LinkURL, &h.LinkTitle, &h.LinkDesc, &h.LinkImage, &h.ChatName); err != nil {
			return nil, err
		}
		if cc != "" {
			_ = json.Unmarshal([]byte(cc), &h.CC)
		}
		if bcc != "" {
			_ = json.Unmarshal([]byte(bcc), &h.BCC)
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

// SearchChats finds conversations by name or subject, most recent first.
func (s *HistoryStore) SearchChats(ctx context.Context, query string, limit int) ([]Chat, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, nil
	}
	if limit <= 0 {
		limit = 50
	}

	rows, err := s.db.QueryContext(ctx, chatSelect+`
WHERE c.name LIKE '%' || ? || '%' ESCAPE '\'
   OR c.subject LIKE '%' || ? || '%' ESCAPE '\'
ORDER BY c.last_ts DESC
LIMIT ?`, escapeLike(query), escapeLike(query), limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanChats(rows)
}

// escapeLike neutralises LIKE wildcards in user input, so searching for "100%"
// does not match everything.
func escapeLike(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)
	return r.Replace(s)
}

// Tags the host can work out for itself, so filtering on them works even for a
// provider that declares none of its own.
const (
	TagArchived = "archived"
	TagMuted    = "muted"
	TagUnread   = "unread"
	TagGroup    = "group"
	TagDirect   = "direct"
)

// withDerivedTags merges what the provider declared with what the host knows.
//
// Archived and muted live in columns rather than in the tag list because the
// user changes them here, so they are derived on read instead of being stored
// twice and drifting apart.
func withDerivedTags(c Chat) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(c.Tags)+3)

	add := func(tag string) {
		if tag == "" || seen[tag] {
			return
		}
		seen[tag] = true
		out = append(out, tag)
	}

	for _, tag := range c.Tags {
		add(tag)
	}

	if c.Archived {
		add(TagArchived)
	}
	if c.Muted {
		add(TagMuted)
	}
	if c.Unread > 0 {
		add(TagUnread)
	}
	if c.IsGroup {
		add(TagGroup)
	} else {
		add(TagDirect)
	}

	return out
}

// KnownTags lists every tag any conversation carries, so a filter can offer
// what actually exists rather than a hardcoded set.
func (s *HistoryStore) KnownTags(ctx context.Context) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT tags FROM chats WHERE tags != ''`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	seen := map[string]bool{}
	for rows.Next() {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			return nil, err
		}
		var tags []string
		if json.Unmarshal([]byte(raw), &tags) != nil {
			continue
		}
		for _, tag := range tags {
			if tag != "" {
				seen[tag] = true
			}
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// The derived ones are always available, whether or not any provider
	// happens to declare them.
	for _, tag := range []string{TagArchived, TagMuted, TagUnread, TagGroup, TagDirect} {
		seen[tag] = true
	}

	out := make([]string, 0, len(seen))
	for tag := range seen {
		out = append(out, tag)
	}
	sort.Strings(out)
	return out, nil
}

// ---------------------------------------------------------------- meta

// GetMeta reads a per-provider value, returning "" when unset.
func (s *HistoryStore) GetMeta(ctx context.Context, provider, key string) (string, error) {
	var v string
	err := s.db.QueryRowContext(ctx,
		`SELECT v FROM meta WHERE provider = ? AND k = ?`, provider, key).Scan(&v)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return v, err
}

// SetMeta writes a per-provider value.
func (s *HistoryStore) SetMeta(ctx context.Context, provider, key, value string) error {
	_, err := s.db.ExecContext(ctx, `
INSERT INTO meta (provider, k, v) VALUES (?,?,?)
ON CONFLICT(provider, k) DO UPDATE SET v = excluded.v`, provider, key, value)
	return err
}

// ---------------------------------------------------------------- maintenance

// PurgeProvider removes everything belonging to a provider. Used when a user
// signs out or uninstalls a chat plugin.
func (s *HistoryStore) PurgeProvider(ctx context.Context, provider string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, stmt := range []string{
		`DELETE FROM messages WHERE provider = ?`,
		`DELETE FROM chats    WHERE provider = ?`,
		`DELETE FROM meta     WHERE provider = ?`,
	} {
		if _, err := tx.ExecContext(ctx, stmt, provider); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// TrimOlderThan deletes messages older than cutoff, honouring the user's
// history-retention setting. Chats are left in place so the conversation list
// survives a retention sweep.
func (s *HistoryStore) TrimOlderThan(ctx context.Context, cutoff int64) (int64, error) {
	res, err := s.db.ExecContext(ctx, `DELETE FROM messages WHERE ts < ?`, cutoff)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// MediaPaths lists every cached attachment path, so the media cache can tell
// which files on disk are still referenced.
func (s *HistoryStore) MediaPaths(ctx context.Context) ([]string, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT media_path FROM messages WHERE media_path != ''`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var p string
		if err := rows.Scan(&p); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
