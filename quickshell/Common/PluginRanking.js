.pragma library

// Ranking for the plugin browser: recommendations, trending, picks of the
// day and of the week. Pure functions over the registry list, no I/O.
//
// A plugin is what the plugin list returns: id, category, author, upvotes,
// status, similar, compositors, firstParty, featured, installed, created_at,
// updated_at. Dates are ISO strings; a missing date is treated as old.

const DAY_MS = 86400000;

function _time(value) {
    const t = Date.parse(value || "");
    return isNaN(t) ? 0 : t;
}

function _days(from, now) {
    if (!from)
        return 3650;
    return Math.max(0, (now - from) / DAY_MS);
}

// Registry lists reach QML as sequences that Array.isArray() rejects.
function _list(value) {
    if (!value || typeof value !== "object" || typeof value.length !== "number")
        return [];
    const out = [];
    for (let i = 0; i < value.length; i++)
        out.push(value[i]);
    return out;
}

function _has(list, value) {
    return _list(list).indexOf(value) >= 0;
}

function isUsable(plugin, compositor) {
    if (!plugin || !plugin.id)
        return false;
    if (_has(plugin.status, "broken") || _has(plugin.status, "unmaintained"))
        return false;
    const comps = _list(plugin.compositors);
    if (!compositor || comps.length === 0 || _has(comps, "any"))
        return true;
    return _has(comps, compositor);
}

// Compositors a plugin is limited to when the running one is not among them, else [].
function unsupportedOn(plugin, compositor) {
    const comps = _list(plugin ? plugin.compositors : null);
    if (!compositor || comps.length === 0 || _has(comps, "any") || _has(comps, compositor))
        return [];
    return comps;
}

// filters: { usable, fresh, official }, every set one has to match.
function matchesFilters(plugin, filters, compositor, now) {
    if (!filters)
        return true;
    if (filters.usable && !isUsable(plugin, compositor))
        return false;
    if (filters.fresh && recency(plugin, now) === "")
        return false;
    if (filters.official && !plugin.firstParty)
        return false;
    return true;
}

// What the user already runs, read from the installed plugins.
function buildTaste(plugins) {
    const taste = {
        installed: {},
        similar: {},
        categories: {},
        authors: {},
        count: 0
    };
    for (let i = 0; i < plugins.length; i++) {
        const p = plugins[i];
        if (!p.installed)
            continue;
        taste.installed[p.id] = true;
        taste.count++;
        const cat = (p.category || "").toLowerCase();
        if (cat)
            taste.categories[cat] = (taste.categories[cat] || 0) + 1;
        if (p.author)
            taste.authors[p.author] = (taste.authors[p.author] || 0) + 1;
        const sim = p.similar || [];
        for (let s = 0; s < sim.length; s++)
            taste.similar[sim[s]] = (taste.similar[sim[s]] || 0) + 1;
    }
    return taste;
}

// Votes with diminishing returns: the 40th vote weighs less than the 4th.
function popularity(plugin) {
    return Math.log(1 + Math.max(0, plugin.upvotes || 0)) / Math.LN2;
}

// Votes per unit of age, so a young plugin that gathers votes fast outranks
// an old one sitting on the same count. The two-week offset keeps a plugin
// published an hour ago from winning on a single vote.
function trending(plugin, now) {
    const age = _days(_time(plugin.created_at), now);
    return (plugin.upvotes || 0) / Math.pow(age + 14, 0.8);
}

// 1 on the day of the last update, halves every 45 days.
function freshness(plugin, now) {
    const age = _days(_time(plugin.updated_at), now);
    return Math.pow(0.5, age / 45);
}

// "new" for two weeks after a plugin enters the registry, "updated" for a
// week after a release, "" otherwise. Drives the badge on the browser cards.
function recency(plugin, now) {
    const t = now || Date.now();
    if (_days(_time(plugin.created_at), t) <= 14)
        return "new";
    if (_days(_time(plugin.updated_at), t) <= 7)
        return "updated";
    return "";
}

function affinity(plugin, taste) {
    if (!taste || taste.count === 0)
        return 0;
    let score = 0;
    if (taste.similar[plugin.id])
        score += 2 + Math.min(2, taste.similar[plugin.id] - 1);
    const sim = plugin.similar || [];
    for (let s = 0; s < sim.length; s++) {
        if (taste.installed[sim[s]]) {
            score += 1;
            break;
        }
    }
    const cat = (plugin.category || "").toLowerCase();
    if (cat && taste.categories[cat])
        score += Math.min(1, taste.categories[cat] / taste.count * 2);
    if (plugin.author && taste.authors[plugin.author])
        score += 0.5;
    return score;
}

function trust(plugin) {
    let score = 0;
    if (_has(plugin.status, "reviewed"))
        score += 1;
    if (plugin.firstParty)
        score += 0.5;
    if (plugin.featured)
        score += 1;
    return score;
}

function scoreParts(plugin, taste, now) {
    return {
        popularity: popularity(plugin),
        trending: trending(plugin, now) * 4,
        freshness: freshness(plugin, now) * 1.5,
        affinity: affinity(plugin, taste) * 1.5,
        trust: trust(plugin)
    };
}

function score(plugin, taste, now) {
    const p = scoreParts(plugin, taste, now);
    return p.popularity + p.trending + p.freshness + p.affinity + p.trust;
}

// The strongest reason a plugin is shown, as a stable key the UI translates.
function reason(plugin, taste, now) {
    if (taste && taste.similar[plugin.id])
        return "similar";
    if (plugin.featured)
        return "featured";
    const parts = scoreParts(plugin, taste, now);
    if (_days(_time(plugin.created_at), now) <= 14)
        return "new";
    if (parts.trending >= parts.popularity && parts.trending >= parts.affinity)
        return "trending";
    if (parts.affinity > 0 && parts.affinity >= parts.popularity)
        return "category";
    return "popular";
}

function _ranked(plugins, now, options, scoreFn) {
    const compositor = options.compositor;
    const exclude = options.exclude || [];
    const rows = [];
    for (let i = 0; i < plugins.length; i++) {
        const p = plugins[i];
        if (p.installed || !isUsable(p, compositor) || _has(exclude, p.id))
            continue;
        rows.push({
            plugin: p,
            score: scoreFn(p)
        });
    }
    rows.sort((a, b) => {
        if (b.score !== a.score)
            return b.score - a.score;
        return a.plugin.id < b.plugin.id ? -1 : a.plugin.id > b.plugin.id ? 1 : 0;
    });
    return rows;
}

// Best first, with at most `perAuthor` entries by the same author so one
// prolific author cannot fill the shelf. When that leaves the shelf short,
// the skipped entries fill the remaining places in rank order.
function _diverse(rows, limit, perAuthor) {
    const out = [];
    const skipped = [];
    const seen = {};
    for (let i = 0; i < rows.length && out.length < limit; i++) {
        const author = rows[i].plugin.author || "";
        seen[author] = (seen[author] || 0) + 1;
        if (author && seen[author] > perAuthor) {
            skipped.push(rows[i].plugin);
            continue;
        }
        out.push(rows[i].plugin);
    }
    for (let i = 0; i < skipped.length && out.length < limit; i++)
        out.push(skipped[i]);
    return out;
}

function recommend(plugins, options) {
    const o = options || {};
    const now = o.now || Date.now();
    const taste = o.taste || buildTaste(plugins);
    const rows = _ranked(plugins, now, o, p => score(p, taste, now));
    return _diverse(rows, o.limit || 8, o.perAuthor || 2);
}

function trendingNow(plugins, options) {
    const o = options || {};
    const now = o.now || Date.now();
    const rows = _ranked(plugins, now, o, p => trending(p, now)).filter(r => r.score > 0);
    return _diverse(rows, o.limit || 8, o.perAuthor || 2);
}

function newArrivals(plugins, options) {
    const o = options || {};
    const now = o.now || Date.now();
    const maxAge = o.maxAgeDays || 14;
    const rows = _ranked(plugins, now, o, p => _time(p.created_at)).filter(r => r.score > 0 && _days(r.score, now) <= maxAge);
    return _diverse(rows, o.limit || 8, o.perAuthor || 2);
}

function _dayNumber(now) {
    return Math.floor(now / DAY_MS);
}

// Weeks start on Monday (day 0 of the epoch was a Thursday).
function _weekNumber(now) {
    return Math.floor((_dayNumber(now) + 3) / 7);
}

function _hash(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) {
        h ^= text.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return h >>> 0;
}

// One pick per period, the same for everybody on the same day: drawn from the
// best reviewed plugins that have a screenshot, rotated by the date so the
// spot moves on instead of showing the top plugin forever. Installed plugins
// stay eligible on purpose: the pick is a shared headline, not a suggestion.
function _pick(plugins, now, key, poolSize, excludeId) {
    const rows = [];
    for (let i = 0; i < plugins.length; i++) {
        const p = plugins[i];
        if (!isUsable(p, "") || !_has(p.status, "reviewed") || !p.screenshot || p.id === excludeId)
            continue;
        rows.push({
            plugin: p,
            score: popularity(p) + trending(p, now) * 4 + freshness(p, now)
        });
    }
    if (rows.length === 0)
        return null;
    rows.sort((a, b) => b.score !== a.score ? b.score - a.score : (a.plugin.id < b.plugin.id ? -1 : 1));
    const pool = rows.slice(0, Math.min(poolSize, rows.length));
    return pool[_hash(key) % pool.length].plugin;
}

function pickOfTheWeek(plugins, now) {
    const t = now || Date.now();
    return _pick(plugins, t, "week:" + _weekNumber(t), 12, "");
}

function pickOfTheDay(plugins, now) {
    const t = now || Date.now();
    const week = pickOfTheWeek(plugins, t);
    return _pick(plugins, t, "day:" + _dayNumber(t), 30, week ? week.id : "");
}
