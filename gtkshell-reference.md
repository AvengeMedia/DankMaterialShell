## hyprland.cpp
\`\`\`

#include <giomm.h>
#include <glibmm.h>
#include <gtkmm/box.h>
#include <gtkmm/label.h>
#include <gtkmm/checkbutton.h>
#include <gtkmm/spinbutton.h>
#include <gtkmm/frame.h>
#include <gtkmm/separator.h>

#include <format>

#include "hyprland.h"
#include "utils.h"
#include "bind.h"

#include <nlohmann/json.hpp>
using json = nlohmann::json;

Hyprland::Hyprland() :
    Glib::ObjectBase(typeid(Hyprland)),
    scroller_mode(*this, "scroller-mode", {}),
    scroller_overview(*this, "scroller-overview", false),
    scroller_trail(*this, "scroller-trail", { -1, 0 }),
    scroller_trailmark(*this, "scroller-trailmark", false),
    scroller_mark(*this, "scroller-mark", { false, "" }),
    workspacev2(*this, "workspacev2", { 1, "" }),
    activespecial(*this, "activespecial", ""),
    activewindow(*this, "activewindow", ""),
    activelayout(*this, "activelayout", ""),
    submap(*this, "submap", "")
{
    prepare();
    watch_socket();
    sync_workspaces();
    sync_client();
    sync_layout();
}
Hyprland::~Hyprland() {}

Hyprland &Hyprland::get_instance()
{
    static Hyprland instance;
    return instance;
}

std::string Hyprland::sock(const std::string &pre, const std::string &HIS, const std::string &socket) const
{
    return std::format("{}/hypr/{}/.{}.sock", pre, HIS, socket);
}

void Hyprland::prepare()
{
    const auto HIS = Glib::getenv("HYPRLAND_INSTANCE_SIGNATURE");
    const auto XRD = Glib::getenv("XDG_RUNTIME_DIR");
    const std::string XDG_RUNTIME_DIR = XRD != "" ? XRD : "/";

    const auto path_events = Glib::file_test(sock(XDG_RUNTIME_DIR, HIS, "socket2"), Glib::FileTest::EXISTS) ?
        sock(XDG_RUNTIME_DIR, HIS, "socket2") : sock("/tmp", HIS, "socket2");
    const auto path_requests = Glib::file_test(sock(XDG_RUNTIME_DIR, HIS, "socket"), Glib::FileTest::EXISTS) ?
        sock(XDG_RUNTIME_DIR, HIS, "socket") : sock("/tmp", HIS, "socket");

    client_events = Gio::SocketClient::create();
    address_events = Gio::UnixSocketAddress::create(path_events);
    client_requests = Gio::SocketClient::create();
    address_requests = Gio::UnixSocketAddress::create(path_requests);
    connection = client_events->connect(address_events);
    listener = Gio::DataInputStream::create(connection->get_input_stream());
    listener->set_close_base_stream(true);
}

void Hyprland::watch_socket()
{
    listener->read_line_async([this](auto &result) {
                              std::string line;
                              listener->read_line_finish(result, line);
                              event_decode(line);
                              watch_socket();
                              }, nullptr);
}

void Hyprland::sync_workspaces(bool notify)
{
    json json_workspaces = json::parse(message("j/workspaces"));
    workspaces.clear();
    for (auto workspace : json_workspaces) {
        int id = workspace["id"].get<int>();
        auto name = workspace["name"].get<std::string>();
        workspaces[id] = name;
    }
    json json_activeworkspace = json::parse(message("j/activeworkspace"));
    workspacev2.set_value({ json_activeworkspace["id"].get<int>(), json_activeworkspace["name"].get<std::string>() });

    signal_workspaces.emit();
}

void Hyprland::sync_client(bool notify)
{
    json json_activewindow = json::parse(message("j/activewindow"));
    // Check if any window is already active
    if (json_activewindow.contains("title"))
        activewindow.set_value(json_activewindow["title"].get<std::string>());
}

void Hyprland::sync_layout(bool notify)
{
    json json_keyboards = json::parse(message("j/devices"))["keyboards"];
    for (auto kb : json_keyboards) {
        if (kb["main"].get<bool>() == true) {
            activelayout.set_value(kb["active_keymap"].get<std::string>());
            return;
        }
    }
}

void Hyprland::event_decode(const std::string &event)
{
    auto msg = Utils::split(event, ">>");
    if (msg[0] == "scroller") {
        // Scroller events
        auto argv = Utils::split(msg[1], ",");
        if (argv[0] == "mode") {
            for (auto &arg : argv)
                arg = Utils::trim(arg);
            scroller_mode.set_value(argv);
        } else if (argv[0] == "overview") {
            scroller_overview.set_value(Utils::trim(argv[1]) == "1" ? true : false);
        } else if (argv[0] == "trail") {
            scroller_trail.set_value({ std::stoi(Utils::trim(argv[1])), std::stoi(Utils::trim(argv[2])) });
        } else if (argv[0] == "trailmark") {
            scroller_trailmark.set_value(Utils::trim(argv[1]) == "1" ? true : false);
        } else if (argv[0] == "mark") {
            scroller_mark.set_value({ Utils::trim(argv[1]) == "1" ? true : false, Utils::trim(argv[2]) });
        }
    } else {
        // Hyprland events
        if (msg[0] == "workspacev2") {
            auto workspace = Utils::split(Utils::trim(msg[1]), ",");
            workspacev2.set_value({ std::stoi(workspace[0]), workspace[1] });
        } else if (msg[0] == "focusedmonv2") {
            auto workspace = Utils::split(Utils::trim(msg[1]), ",");
            int id = std::stoi(workspace[1]);
            workspacev2.set_value({ id, workspaces[id] });
        } else if (msg[0] == "activewindow") {
            auto name = Utils::split(Utils::trim(msg[1]), ",");
            activewindow.set_value(name[1]);
        } else if (msg[0] == "submap") {
            auto name = Utils::trim(msg[1]);
            submap.set_value(name);
        } else if (msg[0] == "createworkspacev2") {
            sync_workspaces();
        } else if (msg[0] == "destroyworkspacev2") {
            sync_workspaces();
        } else if (msg[0] == "activespecial") {
            auto workspace = Utils::split(Utils::trim(msg[1]), ",");
            activespecial.set_value(workspace[0]);
        } else if (msg[0] == "activelayout") {
            auto keyboard = Utils::trim(msg[1]);
            activelayout.set_value(keyboard.substr(keyboard.find(",") + 1));
        }
    }
}

// Hyprland write to socket functions
bool Hyprland::write_socket(const Glib::ustring &message,
                            Glib::RefPtr<Gio::SocketConnection> &connection,
                            Glib::RefPtr<Gio::DataInputStream> &stream)
{
    connection = client_requests->connect(address_requests);
    if (connection != nullptr) {
        connection->get_output_stream()->write(message, nullptr);
        stream = Gio::DataInputStream::create(connection->get_input_stream());
        return true;
    }
    return false;
}

Glib::ustring Hyprland::message(const Glib::ustring &message)
{
    Glib::RefPtr<Gio::SocketConnection> connection;
    Glib::RefPtr<Gio::DataInputStream> stream;
    std::string result;
    if (write_socket(message, connection, stream)) {
        stream->read_upto(result, "\x04");
        connection->close();
    }
    return result;
}

void Hyprland::message_async(const Glib::ustring &message, std::any data, void (*cb)(std::any data, const Glib::ustring &msg_result))
{
    Glib::RefPtr<Gio::SocketConnection> connection;
    Glib::RefPtr<Gio::DataInputStream> stream;
    if (write_socket(message, connection, stream)) {
        stream->read_upto_async("\x04",
            [data, cb, connection, stream] (Glib::RefPtr<Gio::AsyncResult> &res) {
                std::string result;
                bool ok = stream->read_upto_finish(res, result);
                connection->close();
                if (ok)
                    cb(data, result);
            }, nullptr);
    }
}

void Hyprland::dispatch(const Glib::ustring &dispatcher, const Glib::ustring &args)
{
    message_async("dispatch " + dispatcher + " " + args, nullptr, [] (std::any data, const Glib::ustring &msg_result) {
                  if (msg_result != "ok") {
                    Utils::log(Utils::LogSeverity::ERROR, std::format("Hyprland::dispatch"));
                  }
    });
}

Scroller::Scroller() : auto_entry(Gtk::Adjustment::create(2.0, 1.0, 20.0, 1.0, 5.0, 0.0))
{
    auto &hyprland = Hyprland::get_instance();

    auto r_row = Gtk::make_managed<Gtk::CheckButton>("row");
    r_row->signal_toggled().connect(
        [&hyprland, r_row]() {
            if (r_row->get_active())
                hyprland.dispatch("scroller:setmode", "row");
        });
    auto r_col = Gtk::make_managed<Gtk::CheckButton>("column");
    r_col->signal_toggled().connect(
        [&hyprland, r_col]() {
            if (r_col->get_active())
                hyprland.dispatch("scroller:setmode", "col");
        });
    r_col->set_group(*r_row);
    auto r_frame = Gtk::make_managed<Gtk::Frame>("Mode");
    auto r_frame_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    r_frame_box->append(*r_row);
    r_frame_box->append(*r_col);
    r_frame->set_child(*r_frame_box);
    auto r_separator = Gtk::make_managed<Gtk::Separator>();

    auto p_after = Gtk::make_managed<Gtk::CheckButton>("after");
    p_after->signal_toggled().connect([&hyprland, p_after] () { if (p_after->get_active()) hyprland.dispatch("scroller:setmodemodifier", "after"); });
    auto p_before = Gtk::make_managed<Gtk::CheckButton>("before");
    p_before->signal_toggled().connect([&hyprland, p_before] () { if (p_before->get_active()) hyprland.dispatch("scroller:setmodemodifier", "before"); });
    auto p_beginning = Gtk::make_managed<Gtk::CheckButton>("beginning");
    p_beginning->signal_toggled().connect([&hyprland, p_beginning] () { if (p_beginning->get_active()) hyprland.dispatch("scroller:setmodemodifier", "beginning"); });
    auto p_end = Gtk::make_managed<Gtk::CheckButton>("end");
    p_end->signal_toggled().connect([&hyprland, p_end] () { if (p_end->get_active()) hyprland.dispatch("scroller:setmodemodifier", "end"); });
    p_before->set_group(*p_after);
    p_beginning->set_group(*p_after);
    p_end->set_group(*p_after);
    auto p_frame = Gtk::make_managed<Gtk::Frame>("Position");
    auto p_frame_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    p_frame_box->append(*p_after);
    p_frame_box->append(*p_before);
    p_frame_box->append(*p_beginning);
    p_frame_box->append(*p_end);
    p_frame->set_child(*p_frame_box);
    auto p_separator = Gtk::make_managed<Gtk::Separator>();

    auto f_frame = Gtk::make_managed<Gtk::Frame>("Focus");
    auto f_frame_box = Gtk::make_managed<Gtk::Box>();
    auto f_focus = Gtk::make_managed<Gtk::CheckButton>("focus");
    f_focus->signal_toggled().connect([&hyprland, f_focus]() { if (f_focus->get_active()) hyprland.dispatch("scroller:setmodemodifier", ", focus"); });
    auto f_nofocus = Gtk::make_managed<Gtk::CheckButton>("nofocus");
    f_nofocus->set_group(*f_focus);
    f_nofocus->signal_toggled().connect([&hyprland, f_nofocus]() { if (f_nofocus->get_active()) hyprland.dispatch("scroller:setmodemodifier", ", nofocus"); });
    f_frame_box->append(*f_focus);
    f_frame_box->append(*f_nofocus);
    f_frame->set_child(*f_frame_box);
    auto f_separator = Gtk::make_managed<Gtk::Separator>();

    auto a_frame = Gtk::make_managed<Gtk::Frame>("Automatic");
    auto a_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    auto a_manual = Gtk::make_managed<Gtk::CheckButton>("manual"); 
    a_manual->signal_toggled().connect([&hyprland, a_manual] () { if (a_manual->get_active()) hyprland.dispatch("scroller:setmodemodifier", ", , manual"); });
    auto a_auto_box = Gtk::make_managed<Gtk::Box>();
    auto a_auto = Gtk::make_managed<Gtk::CheckButton>("auto");
    auto a_entry = Gtk::make_managed<Gtk::SpinButton>(auto_entry);
    a_auto_connection = a_auto->signal_toggled().connect(
        [this, &hyprland, a_auto, a_entry]() {
            if (a_auto->get_active()) {
                a_entry_connection.block(true);
                hyprland.dispatch("scroller:setmodemodifier", std::format(", , auto, {}", a_entry->get_value()));
                a_entry_connection.unblock();
            }
        });
    a_entry_connection = a_entry->signal_value_changed().connect(
        [this, &hyprland, a_auto, a_entry]() {
            if (a_auto->get_active()) {
                a_auto_connection.block(true);
                hyprland.dispatch("scroller:setmodemodifier", std::format(", , auto, {}", a_entry->get_value()));
                a_auto_connection.unblock();
            }
        });
    a_auto->set_group(*a_manual);
    a_auto_box->append(*a_auto);
    a_auto_box->append(*a_entry);
    a_box->append(*a_manual);
    a_box->append(*a_auto_box);
    a_frame->set_child(*a_box);
    auto a_separator = Gtk::make_managed<Gtk::Separator>();

    auto c_frame = Gtk::make_managed<Gtk::Frame>("Center");
    auto c_frame_box = Gtk::make_managed<Gtk::Box>();
    auto c_col = Gtk::make_managed<Gtk::CheckButton>("column");
    c_col->signal_toggled().connect([&hyprland, c_col]() {
        if (c_col->get_active())
            hyprland.dispatch("scroller:setmodemodifier", ", center_column");
        else
            hyprland.dispatch("scroller:setmodemodifier", ", nocenter_column");
    });
    auto c_win = Gtk::make_managed<Gtk::CheckButton>("window");
    c_win->signal_toggled().connect([&hyprland, c_win]() {
        if (c_win->get_active())
            hyprland.dispatch("scroller:setmodemodifier", ", center_window");
        else
            hyprland.dispatch("scroller:setmodemodifier", ", nocenter_window");
    });
    c_frame_box->append(*c_col);
    c_frame_box->append(*c_win);
    c_frame->set_child(*c_frame_box);

    mode_label.add_css_class("scroller-mode");
    bind_property_changed(&hyprland, "scroller-mode",
          [this, &hyprland, r_row, r_col, p_after, p_before, p_beginning, p_end, f_focus, f_nofocus, a_manual, a_auto, a_entry] {
              auto scroller_mode = hyprland.scroller_mode.get_value();
              if (scroller_mode.size() == 0)
                  // Initialization, no windows yet, no mode
                  return;
              std::string mode;
              if (scroller_mode[1] == "row") {
                  mode = "-";
                  r_row->set_active(true);
              } else {
                  mode = "|";
                  r_col->set_active(true);
              }
              std::string pos;
              // position
              if (scroller_mode[2] == "after") {
                  pos = "→";
                  p_after->set_active(true);
              } else if (scroller_mode[2] == "before") {
                  pos = "←";
                  p_before->set_active(true);
              } else if (scroller_mode[2] == "end") {
                  pos = "⇥";
                  p_end->set_active(true);
              } else if (scroller_mode[2] == "beginning") {
                  pos = "⇤";
                  p_beginning->set_active(true);
              }
              // focus
              std::string focus;
              if (scroller_mode[3] == "focus") {
                  focus = "";
                  f_focus->set_active(true);
              } else {
                  focus = "";
                  f_nofocus->set_active(true);
              }
              // center column/window
              std::string center_column;
              if (scroller_mode[5] == "center_column") {
                  center_column = "";
              } else {
                  center_column = " ";
              }
              std::string center_window;
              if (scroller_mode[6] == "center_window") {
                  center_window = "󰉠";
              } else {
                  center_window = " ";
              }
              // auto
              bool manual = scroller_mode[4].starts_with("manual:");
              const std::string auto_mode = manual ? "✋" : "🅰";
              if (manual) {
                  a_manual->set_active(true);
                  a_entry->set_editable(false);
                  mode_label.set_text(std::format("{} {} {} {} {} {}  ", mode, pos, focus, center_column, center_window, auto_mode));
              } else {
                  a_auto_connection.block(true);
                  a_entry_connection.block(true);
                  a_entry->set_editable(true);
                  a_auto->set_active(true);
                  // auto:N
                  const std::string auto_param = scroller_mode[4].substr(5);
                  a_entry->set_value(std::stod(auto_param));
                  a_entry_connection.unblock();
                  a_auto_connection.unblock();
                  mode_label.set_text(std::format("{} {} {} {} {} {} {}", mode, pos, focus, center_column, center_window, auto_mode, auto_param));
              }
          });

    overview_label.add_css_class("scroller-overview");
    bind_property_changed(&hyprland, "scroller-overview", [this, &hyprland] {
        auto overview = hyprland.scroller_overview.get_value();
        overview_label.set_text(overview ? "🐦" : "");
    });
    
    mark_label.add_css_class("scroller-mark");
    bind_property_changed(&hyprland, "scroller-mark", [this, &hyprland] {
        auto mark = hyprland.scroller_mark.get_value();
        mark_label.set_text(mark.first ? "🔖 " + mark.second : "");
    });
    
    trailmark_label.add_css_class("scroller-trailmark");
    bind_property_changed(&hyprland, "scroller-trailmark", [this, &hyprland] {
        auto trailmark = hyprland.scroller_trailmark.get_value();
        trailmark_label.set_text(trailmark ? "✅" : "");
    });

    trail_label.add_css_class("scroller-trail");
    bind_property_changed(&hyprland, "scroller-trail", [this, &hyprland] {
        auto trail = hyprland.scroller_trail.get_value();
        trail_label.set_text(trail.first != -1 ? std::format("{} ({})", trail.first, trail.second) : "");
    });

    add_css_class("scroller");

    popover.set_parent(mode_label);

    auto pop_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    pop_box->append(*r_frame);
    pop_box->append(*r_separator);
    pop_box->append(*p_frame);
    pop_box->append(*p_separator);
    pop_box->append(*f_frame);
    pop_box->append(*f_separator);
    pop_box->append(*a_frame);
    pop_box->append(*a_separator);
    pop_box->append(*c_frame);
    pop_box->set_vexpand(true);
    popover.set_child(*pop_box);

    append(mode_label);
    append(overview_label);
    append(mark_label);
    append(trailmark_label);
    append(trail_label);

    click = Gtk::GestureClick::create();
    click->set_button(1); // 0 = all, 1 = left, 2 = center, 3 = right
    click->signal_pressed().connect([this] (int n_press, double x, double y) {
        auto visible = popover.get_visible();
        if (visible)
            popover.popdown();
        else
            popover.popup();
    }, true);
    mode_label.add_controller(click);
}

Submap::Submap()
{
    auto &hyprland = Hyprland::get_instance();
    add_css_class("submap");
    bind_property_changed(&hyprland, "submap", [this, &hyprland] {
        auto submap = hyprland.submap.get_value();
        this->set_text(submap != "" ? "󰌌    " + submap : "");
    });
}

ClientTitle::ClientTitle()
{
    auto &hyprland = Hyprland::get_instance();
    add_css_class("client");
    set_max_width_chars(80);
    set_ellipsize(Pango::EllipsizeMode::END);
    bind_property_changed(&hyprland, "activewindow", [this, &hyprland] {
        auto client = hyprland.activewindow.get_value();
        this->set_text(client);
    });
}

KeyboardLayout::KeyboardLayout()
{
    auto &hyprland = Hyprland::get_instance();
    add_css_class("keyboard");
    bind_property_changed(&hyprland, "activelayout", [this, &hyprland]() {
        auto keyboard = hyprland.activelayout.get_value();
        this->set_text(keyboard);
    });
}

Workspaces::Workspaces()
{
    add_css_class("workspaces");
    auto &hyprland = Hyprland::get_instance();

    auto workspaces_update = [this, &hyprland] () {
        const std::vector<Glib::ustring> normal = { "" };
        const std::vector<Glib::ustring> focused = { "focused" };
        auto active = hyprland.workspacev2.get_value();
        auto activespecial = hyprland.activespecial.get_value();
        for (auto workspace : workspaces) {
            if (activespecial != "") {
                // There is a special workspace active
                auto name = hyprland.workspaces[workspace.first];
                workspace.second->set_css_classes(name == activespecial ? focused : normal);
            } else {
                workspace.second->set_css_classes(workspace.first == active.first ? focused : normal);
            }
            if (workspace.first < 0)
                workspace.second->add_css_class("special");
        }
    };

    hyprland.signal_workspaces.connect([this, &hyprland, workspaces_update] () {
        for (auto workspace : workspaces) {
            remove(*workspace.second);
            delete workspace.second;
        }
        workspaces.clear();
        for (auto workspace : hyprland.workspaces) {
            Gtk::Button *button = new Gtk::Button();
            const int &id = workspace.first;
            const Glib::ustring name = workspace.second;
            if (id < 0)
                button->set_label(std::format("S{}", 99 + id));
            else
                button->set_label(name);
            button->signal_clicked().connect(
                [id, name, &hyprland]() {
                    auto active = hyprland.workspacev2.get_value();
                    auto activespecial = hyprland.activespecial.get_value();
                    auto activespecialname = activespecial == "" ? "" : activespecial.substr(activespecial.find("special:") + std::string("special:").size());
                    if (activespecialname != "")
                        // special
                        hyprland.dispatch("togglespecialworkspace", activespecialname);
                    if (id != active.first)
                        hyprland.dispatch("workspace", name);
                });
            workspaces.push_back({ id, button });
            append(*button);
        }
        workspaces_update();
    });
    hyprland.sync_workspaces();

    workspaces_update();
    hyprland.connect_property_changed("workspacev2", workspaces_update);
    hyprland.connect_property_changed("activespecial", workspaces_update);

    // Setup scrolling on widget
    scroll = Gtk::EventControllerScroll::create();
    scroll->set_flags(Gtk::EventControllerScroll::Flags::VERTICAL);
    scroll->signal_scroll().connect([this, &hyprland] (double dx, double dy) -> bool {
        auto cur = hyprland.workspacev2.get_value().first;
        if (dy > 0.0) {
            if (cur < 10)
                hyprland.dispatch("workspace", "+1");
        } else if (dy < 0.0) {
            if (cur > 1)
                hyprland.dispatch("workspace", "-1");
        }
        return true;
    }, true);
    add_controller(scroll);
}

\`\`\`

## hyprland.h
\`\`\`

#ifndef __GTKSHELL_HYPRLAND__
#define __GTKSHELL_HYPRLAND__

#include <giomm.h>
#include <glibmm.h>
#include <gtkmm/box.h>
#include <gtkmm/label.h>
#include <gtkmm/button.h>
#include <gtkmm/eventcontrollerscroll.h>
#include <gtkmm/gestureclick.h>
#include <gtkmm/popover.h>
#include <gtkmm/adjustment.h>

#include <any>

class Hyprland : public Glib::Object {
public:
    static Hyprland &get_instance();

    // Avoid copy creation
    Hyprland(const Hyprland &) = delete;
    void operator=(const Hyprland &) = delete;

    void dispatch(const Glib::ustring &dispatcher, const Glib::ustring &args);
    void sync_workspaces(bool notify = true);
    void sync_client(bool notify = true);

    // Scroller Properties
    Glib::Property<std::vector<std::string>> scroller_mode;
    Glib::Property<bool> scroller_overview;
    Glib::Property<std::pair<int, int>> scroller_trail;
    Glib::Property<bool> scroller_trailmark;
    Glib::Property<std::pair<bool, Glib::ustring>> scroller_mark;

    // Hyprland Properties
    Glib::Property<std::pair<int, Glib::ustring>> workspacev2;
    Glib::Property<Glib::ustring> activespecial;
    Glib::Property<Glib::ustring> activewindow;
    Glib::Property<Glib::ustring> activelayout;
    Glib::Property<Glib::ustring> submap;

    sigc::signal<void()> signal_workspaces;
    std::map<int, Glib::ustring> workspaces;

private:
    Hyprland();
    virtual ~Hyprland();

    std::string sock(const std::string &pre, const std::string &HIS, const std::string &socket) const;
    void prepare();
    void watch_socket();
    void event_decode(const std::string &event);

    bool write_socket(const Glib::ustring &message,
                      Glib::RefPtr<Gio::SocketConnection> &connection,
                      Glib::RefPtr<Gio::DataInputStream> &stream);
    Glib::ustring message(const Glib::ustring &message);
    void message_async(const Glib::ustring &message, std::any data, void (*cb)(std::any data, const Glib::ustring &msg_result));
    //Glib::ustring message_async(const Glib::ustring &message);

    void sync_layout(bool notify = true);

    Glib::RefPtr<Gio::SocketClient> client_events, client_requests;
    Glib::RefPtr<Gio::UnixSocketAddress> address_events, address_requests;
    Glib::RefPtr<Gio::SocketConnection> connection;
    Glib::RefPtr<Gio::DataInputStream> listener;

    Glib::RefPtr<Gio::SocketConnection> connection_requests;
    Glib::RefPtr<Gio::DataInputStream> stream_requests;
};

class Workspaces : public Gtk::Box {
public:
    Workspaces();
    ~Workspaces() {
        for (auto workspace : workspaces)
            delete workspace.second;
    }

private:
    std::vector<std::pair<int, Gtk::Button *>> workspaces;
    Glib::RefPtr<Gtk::EventControllerScroll> scroll;
};

class Submap : public Gtk::Label {
public:
    Submap();
    ~Submap() {}
};

class ClientTitle : public Gtk::Label {
public:
    ClientTitle();
    ~ClientTitle() {}
};

class KeyboardLayout : public Gtk::Label {
public:
    KeyboardLayout();
    ~KeyboardLayout() {}
};

class Scroller : public Gtk::Box {
public:
    Scroller();
    ~Scroller() {}

private:
    Glib::RefPtr<Gtk::GestureClick> click;
    Glib::RefPtr<Gtk::Adjustment> auto_entry;
    Gtk::Popover popover;
    Gtk::Label mode_label;
    Gtk::Label overview_label;
    Gtk::Label mark_label;
    Gtk::Label trailmark_label;
    Gtk::Label trail_label;
    sigc::connection a_auto_connection;
    sigc::connection a_entry_connection;
};

#endif // __GTKSHELL_HYPRLAND__

\`\`\`

## main.cpp
\`\`\`

#include <gtk/gtk.h>
#include <gtkmm.h>

#include <gtkmm/box.h>
#include <gtkmm/centerbox.h>
#include <gtkmm/label.h>
#include <gtkmm/window.h>

#include "main.h"
#include "utils.h"
#include "shellwindow.h"
#include "network.h"
#include "widgets.h"
#include "hyprland.h"
#include "clock.h"
#include "graph.h"
#include "wireplumber.h"
#include "weather.h"
#include "scroll.h"

#include <nlohmann/json.hpp>
using json = nlohmann::json;


static Glib::ustring CONFIG_FILE;
static Glib::ustring STYLE_FILE;

static std::vector<std::string> ARGS;

static Glib::RefPtr<GtkShell> app;

static void reload_stylesheet(const std::string &style_file)
{
    try {
        std::string css_style = Glib::file_get_contents(style_file);
        auto display = Gdk::Display::get_default();
        auto provider = Gtk::CssProvider::create();
        provider->load_from_string(css_style);
        Gtk::StyleContext::add_provider_for_display(display, provider, GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch (Glib::FileError &error) {
        Utils::log(Utils::LogSeverity::WARNING, std::format("Could not load style file {}, error: {}", style_file.c_str(), error.what()));
    }
}

class Bar {
public:
    Bar(const json &json) : window(nullptr), box(nullptr), left(nullptr), center(nullptr), right(nullptr) {
        if (json.contains("monitor")) {
            monitor = json["monitor"];
        } else {
            monitor = Utils::get_default_monitor_id();
        }

        GtkShellAnchor anchor = GtkShellAnchor::ANCHOR_TOP;
        if (json.contains("anchor")) {
            const std::string anchor_str = json["anchor"];
            if (anchor_str == "bottom")
                anchor = GtkShellAnchor::ANCHOR_BOTTOM;
            else if (anchor_str == "left")
                anchor = GtkShellAnchor::ANCHOR_LEFT;
            else if (anchor_str == "right")
                anchor = GtkShellAnchor::ANCHOR_RIGHT;
        }

        GtkShellStretch stretch;
        if (json.contains("stretch")) {
            const std::string stretch_str = json["stretch"];
            if (stretch_str == "none") {
                stretch = GtkShellStretch::STRETCH_NONE;
            } else if (stretch_str == "horizontal") {
                stretch = GtkShellStretch::STRETCH_HORIZONTAL;
            } else if (stretch_str == "vertical") {
                stretch = GtkShellStretch::STRETCH_VERTICAL;
            }
        } else {
            switch (anchor) {
            case GtkShellAnchor::ANCHOR_TOP:
            case GtkShellAnchor::ANCHOR_BOTTOM:
                stretch = GtkShellStretch::STRETCH_HORIZONTAL;
                break;
            case GtkShellAnchor::ANCHOR_LEFT:
            case GtkShellAnchor::ANCHOR_RIGHT:
                stretch = GtkShellStretch::STRETCH_VERTICAL;
                break;
            case GtkShellAnchor::ANCHOR_NONE:
            default:
                stretch = GtkShellStretch::STRETCH_NONE;
                break;
            }
        }
        bool exclusive = true;
        if (json.contains("exclusive") && json["exclusive"] == false)
            exclusive = false;

        window = new GtkShellWindow(("gtkshell-bar-" + monitor).c_str(), anchor, monitor.c_str(), exclusive, stretch);

        window->add_css_class("bar");
        add_widgets(json);
        window->set_child(*box);

        // Add reload menu
        auto model = Gio::Menu::create();
        action_group = Gio::SimpleActionGroup::create();
        action_group->add_action("style", []() {
            reload_stylesheet(STYLE_FILE);
        });
        action_group->add_action("restart", []() {
            Utils::spawn(ARGS, Utils::CWD);
            app->quit();
        });
        model->append("Reload style sheet", "menu.style");
        model->append("Restart", "menu.restart");
        menu.set_menu_model(model);
        box->insert_action_group("menu", action_group);
        menu.set_parent(*box);

        click = Gtk::GestureClick::create();
        click->set_button(3); // 0 = all, 1 = left, 2 = center, 3 = right
        click->signal_pressed().connect([this] (int n_press, double x, double y) {
            const Gdk::Rectangle rect(x, y, 1, 1);
            menu.set_pointing_to(rect);
            menu.popup();
        }, true);
        box->add_controller(click);
    }
    ~Bar() {
        delete window;
    }

    GtkShellWindow *get_window() {
        return window;
    }

private:
    Gtk::Widget *create_widget(const std::string &name) {
        if (name == "workspaces") {
            return Gtk::make_managed<Workspaces>();
        } else if (name == "scroller") {
            return Gtk::make_managed<Scroller>();
        } else if (name == "submap") {
            return Gtk::make_managed<Submap>();
        } else if (name == "client-title") {
            return Gtk::make_managed<ClientTitle>();
        } else if (name == "mpris") {
            return Gtk::make_managed<MediaPlayerBox>();
        } else if (name == "clock") {
            return Gtk::make_managed<Clock>();
        } else if (name == "package-updates") {
            return Gtk::make_managed<PackageUpdates>();
        } else if (name == "idle-inhibitor") {
            return Gtk::make_managed<IdleInhibitor>();
        } else if (name == "keyboard-layout") {
            return Gtk::make_managed<KeyboardLayout>();
        } else if (name == "weather") {
            return Gtk::make_managed<Weather>(1200);
        } else if (name == "screenshot") {
            return Gtk::make_managed<ScreenShot>();
        } else if (name == "cpu-graph") {
            return Gtk::make_managed<CpuGraph>(2, 8, Color(0.0, 0.57, 0.9));
        } else if (name == "mem-graph") {
            return Gtk::make_managed<MemGraph>(5, 8, Color(0.0, 0.7, 0.36));
        } else if (name == "gpu-graph") {
            return Gtk::make_managed<GpuGraph>(5, 8, Color(0.94, 0.78, 0.44), Color(0.65, 0.26, 0.26));
        } else if (name == "network") {
            return Gtk::make_managed<NetworkIndicator>();
        } else if (name == "speaker") {
            return Gtk::make_managed<SpeakerIndicator>();
        } else if (name == "microphone") {
            return Gtk::make_managed<MicrophoneIndicator>();
        } else if (name == "notifications") {
            return Gtk::make_managed<Notifications>(monitor);
        } else if (name == "systray") {
            return Gtk::make_managed<SysTray>();
        } else if (name == "scroll-submap") {
            return Gtk::make_managed<ScrollSubmap>();
        } else if (name == "scroll-workspaces") {
            return Gtk::make_managed<ScrollWorkspaces>(monitor);
        } else if (name == "scroll-client-title") {
            return Gtk::make_managed<ScrollClientTitle>();
        } else if (name == "scroll-keyboard-layout") {
            return Gtk::make_managed<ScrollKeyboardLayout>();
        } else if (name == "scroll-trails") {
            return Gtk::make_managed<ScrollTrails>();
        } else if (name == "scroll-scroller") {
            return Gtk::make_managed<ScrollScroller>();
        }
        return nullptr;
    }
    void add_box_widgets(const json &json, Gtk::Box *box) {
        box->set_hexpand(true);
        box->set_halign(Gtk::Align::FILL);

        if (json.contains("left")) {
            auto left = Gtk::make_managed<Gtk::Box>();
            for (auto module : json["left"]) {
                std::string name = module;
                auto widget = create_widget(name);
                if (widget != nullptr)
                    left->append(*widget);
            }
            left->set_halign(Gtk::Align::START);
            left->set_hexpand(true);
            box->append(*left);
        }
        if (json.contains("right")) {
            auto right = Gtk::make_managed<Gtk::Box>();
            for (auto module : json["right"]) {
                std::string name = module;
                auto widget = create_widget(name);
                if (widget != nullptr)
                    right->append(*widget);
            }
            right->set_halign(Gtk::Align::END);
            right->set_hexpand(true);
            box->append(*right);
        }
    }

    void add_widgets(const json &json) {
        box = Gtk::make_managed<Gtk::CenterBox>();

        if (json.contains("left-box")) {
            auto left_json = json["left-box"];
            if (left_json.size() > 0) {
                left = Gtk::make_managed<Gtk::Box>();
                left->set_halign(Gtk::Align::START);
                left->set_hexpand(true);
                add_box_widgets(left_json, left);
                box->set_start_widget(*left);
            }
        }
        if (json.contains("center-box")) {
            auto center_json = json["center-box"];
            if (center_json.size() > 0) {
                center = Gtk::make_managed<Gtk::Box>();
                center->set_halign(Gtk::Align::CENTER);
                center->set_hexpand(true);
                add_box_widgets(center_json, center);
                center->set_hexpand(false);
                center->set_halign(Gtk::Align::CENTER);
                box->set_center_widget(*center);
            }
        }
        if (json.contains("right-box")) {
            auto right_json = json["right-box"];
            if (right_json.size() > 0) {
                right = Gtk::make_managed<Gtk::Box>();
                right->set_halign(Gtk::Align::END);
                right->set_hexpand(true);
                add_box_widgets(right_json, right);
                box->set_end_widget(*right);
            }
        }
    }

    std::string monitor;
    GtkShellWindow *window;
    Gtk::CenterBox *box;
    Gtk::Box *left, *center, *right;
    Glib::RefPtr<Gtk::GestureClick> click;
    Gtk::PopoverMenu menu;
    Glib::RefPtr<Gio::SimpleActionGroup> action_group;
};

GtkShell::~GtkShell()
{
    for (auto bar : bars)
        delete bar;
}
     
Glib::RefPtr<GtkShell> GtkShell::create(const Glib::ustring &app_id)
{
    return Glib::make_refptr_for_instance<GtkShell>(new GtkShell(app_id));
}

void GtkShell::on_activate()
{
    // Parse json config and create bars
    auto config = Utils::read_file(CONFIG_FILE);
    json json;
    try {
        json = json::parse(config, /* callback */ nullptr, /* allow exceptions */ true, /* ignore comments */ true);
    } catch (const json::parse_error& e) {
        Utils::log(Utils::LogSeverity::ERROR, std::format("message: {}\nexception id: {}\nbyte position of error: {}", e.what(), e.id, e.byte));
    }
    for (auto json_bar : json) {
        auto bar = new Bar(json_bar);
        GtkShellWindow *win = bar->get_window();
        add_window(*win);
        bars.push_back(bar);
        win->present();
    }
}

GtkShell::GtkShell(const Glib::ustring &app_id) : Gtk::Application(app_id, Gio::Application::Flags::DEFAULT_FLAGS)
{
}

// -i instance (default = 1)
// -c config (default = ~/.config/gtkshell/config.js)
// -s style.css (default = ~/.config/gtkshell/style.css)
int main (int argc, char **argv)
{
    std::string instance = "1";
    CONFIG_FILE = Utils::XDG_CONFIG_HOME + "/gtkshell/config.json";
    STYLE_FILE = Utils::XDG_CONFIG_HOME + "/gtkshell/style.css";
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-i") == 0) {
            instance = argv[++i];
        } else if (strcmp(argv[i], "-c") == 0) {
            CONFIG_FILE = Utils::expand_directory(argv[++i]);
        } else if (strcmp(argv[i], "-s") == 0) {
            STYLE_FILE = Utils::expand_directory(argv[++i]);
        }
    }
    // Keep a copy of all arguments for possible restart
    for (int i = 0; i < argc; ++i) {
        ARGS.push_back(argv[i]);
    }

    Utils::GTKSHELL_INSTANCE = instance;
    const Glib::ustring app_id = "com.github.dawsers.gtkshell.id" + Utils::GTKSHELL_INSTANCE;

    app = GtkShell::create(app_id);

    // Apply CSS
    reload_stylesheet(STYLE_FILE);

    return app->run();
}

\`\`\`

## main.h
\`\`\`

#ifndef __GTKSHELL_MAIN__
#define __GTKSHELL_MAIN__

#include <gtkmm/application.h>

class Bar;

class GtkShell : public Gtk::Application {
public:
    virtual ~GtkShell();     

    static Glib::RefPtr<GtkShell> create(const Glib::ustring &app_id);

    void on_activate();

private:
    GtkShell(const Glib::ustring &app_id);

    std::vector<Bar *> bars;
};

#endif

\`\`\`

## scroll.cpp
\`\`\`

#include <giomm.h>
#include <glibmm.h>
#include <gtkmm/box.h>
#include <gtkmm/label.h>
#include <gtkmm/checkbutton.h>
#include <gtkmm/spinbutton.h>
#include <gtkmm/frame.h>
#include <gtkmm/separator.h>

#include <format>

#include "scroll.h"
#include "utils.h"

#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <nlohmann/json.hpp>
using json = nlohmann::json;

ScrollIpc::ScrollIpc() : dispatcher(), sem(0), working(false) {
    const std::string &path = get_socket_path();
    fd = open(path);
    fd_event = open(path);

    worker_thread = std::make_shared<std::thread>(&ScrollIpc::working_thread, this);
    worker_thread->detach();
    dispatcher.connect(
        [this]() {
            mtx.lock();
            auto result = shared_data;
            mtx.unlock();
            signal_event.emit(result);
            sem.release();
        });
}

void ScrollIpc::working_thread() {
    while (true) {
        sem.acquire();
        working = true;
        const auto res = ScrollIpc::recv(fd_event);
        mtx.lock();
        shared_data = res;
        mtx.unlock();
        dispatcher.emit();
        working = false;
    }
}

ScrollIpc::~ScrollIpc() {
    if (fd > 0) {
        // To fail the IPC header
        if (write(fd, "close-sway-ipc", 14) == -1) {
            Utils::log(Utils::LogSeverity::ERROR, "Scroll: Failed to close IPC");
        }
        close(fd);
        fd = -1;
    }
    if (fd_event > 0) {
        if (write(fd_event, "close-sway-ipc", 14) == -1) {
            Utils::log(Utils::LogSeverity::ERROR, "Scroll: Failed to close IPC event handler");
        }
        close(fd_event);
        fd_event = -1;
    }
}

const std::string ScrollIpc::get_socket_path() const {
    const char *env = getenv("SCROLLSOCK");
    if (env != nullptr) {
        return std::string(env);
    }
    throw std::runtime_error("Scroll: SCROLLSOCK variable is empty");
    return "";
}

int ScrollIpc::open(const std::string &socketPath) const {
    int32_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd == -1) {
        throw std::runtime_error("Scroll: Unable to open Unix socket");
    }
    (void)fcntl(fd, F_SETFD, FD_CLOEXEC);
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(struct sockaddr_un));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socketPath.c_str(), sizeof(addr.sun_path) - 1);
    addr.sun_path[sizeof(addr.sun_path) - 1] = 0;
    int l = sizeof(struct sockaddr_un);
    if (::connect(fd, reinterpret_cast<struct sockaddr *>(&addr), l) == -1) {
        throw std::runtime_error("Scroll: Unable to connect");
    }
    return fd;
}

ScrollIpcResponse ScrollIpc::recv(int fd) {
    std::string header;
    header.resize(ipc_header_size);
    auto data32 = reinterpret_cast<uint32_t *>(header.data() + ipc_magic.size());
    size_t total = 0;

    while (total < ipc_header_size) {
        auto res = ::recv(fd, header.data() + total, ipc_header_size - total, 0);
        if (fd_event == -1 || fd == -1) {
            // IPC is closed so just return an empty response
            return {0, 0, ""};
        }
        if (res <= 0) {
            throw std::runtime_error("Scroll: Unable to receive IPC header");
        }
        total += res;
    }
    auto magic = std::string(header.data(), header.data() + ipc_magic.size());
    if (magic != ipc_magic) {
        throw std::runtime_error("Scroll: Invalid IPC magic");
    }

    total = 0;
    std::string payload;
    payload.resize(data32[0]);
    while (total < data32[0]) {
        auto res = ::recv(fd, payload.data() + total, data32[0] - total, 0);
        if (res < 0) {
            if (errno == EINTR || errno == EAGAIN) {
                continue;
            }
            throw std::runtime_error("Scroll: Unable to receive IPC payload");
        }
        total += res;
    }
    return { data32[0], data32[1], payload };
}

ScrollIpcResponse ScrollIpc::send(int fd, uint32_t type, const std::string &payload) {
    std::string header;
    header.resize(ipc_header_size);
    auto data32 = reinterpret_cast<uint32_t *>(header.data() + ipc_magic.size());
    memcpy(header.data(), ipc_magic.c_str(), ipc_magic.size());
    data32[0] = payload.size();
    data32[1] = type;

    if (::send(fd, header.data(), ipc_header_size, 0) == -1) {
        throw std::runtime_error("Scroll: Unable to send IPC header");
    }
    if (::send(fd, payload.c_str(), payload.size(), 0) == -1) {
        throw std::runtime_error("Scroll: Unable to send IPC payload");
    }
    return ScrollIpc::recv(fd);
}

void ScrollIpc::send_cmd(uint32_t type, const std::string &payload) {
    const auto res = ScrollIpc::send(fd, type, payload);
    signal_cmd.emit(res);
}

void ScrollIpc::subscribe(const std::string &payload) {
    auto res = ScrollIpc::send(fd_event, IPC_SUBSCRIBE, payload);
    if (res.payload != "{\"success\": true}") {
        throw std::runtime_error("Scroll: Unable to subscribe ipc event");
    }
    sem.release();
}


// ScrollSubmap
ScrollSubmap::ScrollSubmap()
{
    add_css_class("submap");
    ipc.signal_event.connect(sigc::mem_fun(*this, &ScrollSubmap::on_event));
    ipc.subscribe(R"(["mode"])");
}

void ScrollSubmap::on_event(const ScrollIpcResponse &res) {
    json json_mode = json::parse(res.payload);
    std::string mode = json_mode["change"];
    this->set_text(mode != "default" ? "󰌌    " + mode : "");
}

// ScrollWorkspaces
ScrollWorkspaces::ScrollWorkspaces(const std::string &output) : output(output) {
    add_css_class("workspaces");

    ipc.signal_event.connect(sigc::mem_fun(*this, &ScrollWorkspaces::on_event));
    ipc.signal_cmd.connect(sigc::mem_fun(*this, &ScrollWorkspaces::on_cmd));
    ipc.subscribe(R"(["workspace"])");
    ipc.send_cmd(IPC_GET_WORKSPACES);
}

void ScrollWorkspaces::workspaces_update() {
    const std::vector<Glib::ustring> normal = { "" };
    const std::vector<Glib::ustring> focused = { "focused" };
    for (auto workspace : workspaces) {
        workspace.second->set_css_classes(workspace.first.id == this->focused ? focused : normal);
        if (workspace.first.urgent)
            workspace.second->add_css_class("urgent");
    }
}

void ScrollWorkspaces::on_event(const ScrollIpcResponse &data) {
    json json_mode = json::parse(data.payload);
    std::string change = json_mode["change"];

    if (change == "init") {
        ipc.send_cmd(IPC_GET_WORKSPACES);
    } else if (change == "empty") {
        ipc.send_cmd(IPC_GET_WORKSPACES);
    } else if (change == "focus") {
        json json_current = json_mode["current"];
        std::string output = json_current["output"].get<std::string>();
        if (output == this->output) {
            int num = json_current["num"].get<int>();
            this->focused = num;
        }
        workspaces_update();
    } else if (change == "move") {
        ipc.send_cmd(IPC_GET_WORKSPACES);
    } else if (change == "rename") {
        ipc.send_cmd(IPC_GET_WORKSPACES);
    } else if (change == "urgent") {
        json json_current = json_mode["current"];
        std::string output = json_current["output"].get<std::string>();
        if (output == this->output) {
            int id = json_current["num"].get<int>();
            bool urgent = json_current["urgent"].get<bool>();
            for (auto &workspace : workspaces) {
                if (workspace.first.id == id) {
                    workspace.first.urgent = urgent;
                    break;
                }
            }
            workspaces_update();
        }
    } else if (change == "reload") {
        ipc.send_cmd(IPC_GET_WORKSPACES);
    }
}

void ScrollWorkspaces::on_cmd(const ScrollIpcResponse &data) {
    if (data.type == IPC_GET_WORKSPACES) {
        for (auto workspace : workspaces) {
            remove(*workspace.second);
            delete workspace.second;
        }
        workspaces.clear();
        json json_workspaces = json::parse(data.payload);
        for (auto workspace : json_workspaces) {
            if (workspace["output"].get<std::string>() == output) {
                Gtk::Button *button = new Gtk::Button();
                int id = workspace["num"].get<int>();
                bool focused = workspace["focused"].get<bool>();
                if (focused) {
                    this->focused = id;
                }
                bool urgent = workspace["urgent"].get<bool>();
                const std::string name = workspace["name"].get<std::string>();
                button->set_label(name);
                button->signal_clicked().connect(
                    [id, name, this]() {
                        ipc.send_cmd(IPC_COMMAND, std::format("workspace {}", name));
                    });
                workspaces.push_back({ { id, urgent }, button });
                append(*button);
            }
        }
        workspaces_update();
    }
}

// Scroll ClientTitle
ScrollClientTitle::ScrollClientTitle() {
    add_css_class("client");
    set_max_width_chars(80);
    set_ellipsize(Pango::EllipsizeMode::END);
    ipc.signal_event.connect(sigc::mem_fun(*this, &ScrollClientTitle::on_event));
    ipc.subscribe(R"(["window"])");
}

Glib::ustring ScrollClientTitle::generate_title(const json &container) {
    json marks = container["marks"];
    json trailmark = container["trailmark"];
    const std::string name = container["name"].is_null() ? "" : container["name"].get<std::string>();
    const std::string mark = marks.is_null() || marks.empty() ? "" : "🔖";
    const std::string trail = trailmark.get<bool>() ? "✅" : "";
    return std::format("{} {}{}", name, mark, trail);
}
void ScrollClientTitle::on_event(const ScrollIpcResponse &data) {
    json json_window = json::parse(data.payload);
    std::string change = json_window["change"];
    json container = json_window["container"];
    if (change == "focus") {
        this->focused = container["id"].get<int>();
        this->set_text(generate_title(container));
    } else if (change == "title") {
        if (json_window["container"]["id"].get<int>() == this->focused) {
            this->set_text(generate_title(container));
        }
    } else if (change == "close") {
        if (json_window["container"]["id"].get<int>() == this->focused) {
            this->set_text("");
        }
    } else if (change == "mark") {
        if (json_window["container"]["id"].get<int>() == this->focused) {
            this->set_text(generate_title(container));
        }
    } else if (change == "trailmark") {
        if (json_window["container"]["id"].get<int>() == this->focused) {
            this->set_text(generate_title(container));
        }
    }
}

// Scroll KeyboardLayout
ScrollKeyboardLayout::ScrollKeyboardLayout() {
    add_css_class("keyboard");
    ipc.signal_event.connect(sigc::mem_fun(*this, &ScrollKeyboardLayout::on_event));
    ipc.signal_cmd.connect(sigc::mem_fun(*this, &ScrollKeyboardLayout::on_cmd));
    ipc.subscribe(R"(["input"])");
    // Get current keyboard
    ipc.send_cmd(IPC_GET_INPUTS);
}

void ScrollKeyboardLayout::on_event(const ScrollIpcResponse &data) {
    json json_input = json::parse(data.payload);
    std::string change = json_input["change"];
    if (change == "xkb_layout") {
        this->set_text(json_input["input"]["xkb_active_layout_name"].get<std::string>());
    }
}

void ScrollKeyboardLayout::on_cmd(const ScrollIpcResponse &data) {
    if (data.type == IPC_GET_INPUTS) {
        json json_inputs = json::parse(data.payload);
        for (auto input : json_inputs) {
            if (input["type"].get<std::string>() == "keyboard") {
                this->set_text(input["xkb_active_layout_name"].get<std::string>());
            }
        }
    }
}

// Scroll Trails
ScrollTrails::ScrollTrails() {
    add_css_class("trails");
    ipc.signal_event.connect(sigc::mem_fun(*this, &ScrollTrails::on_event));
    ipc.signal_cmd.connect(sigc::mem_fun(*this, &ScrollTrails::on_cmd));
    ipc.subscribe(R"(["trails"])");
    ipc.send_cmd(IPC_GET_TRAILS);
}

void ScrollTrails::on_event(const ScrollIpcResponse &data) {
    json json_input = json::parse(data.payload);
    int active = json_input["trails"]["active"].get<int>();
    int length = json_input["trails"]["length"].get<int>();
    int nmarks = json_input["trails"]["trail_length"].get<int>();
    const std::string trails = std::format("{}/{} ({})", active, length, nmarks);
    this->set_text(trails);
}

void ScrollTrails::on_cmd(const ScrollIpcResponse &data) {
    if (data.type == IPC_GET_TRAILS) {
        json json_input = json::parse(data.payload);
        int active = json_input["trails"]["active"].get<int>();
        int length = json_input["trails"]["length"].get<int>();
        int nmarks = json_input["trails"]["trail_length"].get<int>();
        const std::string trails = std::format("{}/{} ({})", active, length, nmarks);
        this->set_text(trails);
    }
}

ScrollScroller::ScrollScroller() : auto_entry(Gtk::Adjustment::create(2.0, 1.0, 20.0, 1.0, 5.0, 0.0)) {
    auto r_hor = Gtk::make_managed<Gtk::CheckButton>("horizontal");
    r_hor->signal_toggled().connect(
        [this, r_hor]() {
            if (r_hor->get_active())
                ipc.send_cmd(IPC_COMMAND, "set_mode h");
        });
    auto r_ver = Gtk::make_managed<Gtk::CheckButton>("vertical");
    r_ver->signal_toggled().connect(
        [this, r_ver]() {
            if (r_ver->get_active())
                ipc.send_cmd(IPC_COMMAND, "set_mode v");
        });
    r_ver->set_group(*r_hor);
    auto r_frame = Gtk::make_managed<Gtk::Frame>("Mode");
    auto r_frame_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    r_frame_box->append(*r_hor);
    r_frame_box->append(*r_ver);
    r_frame->set_child(*r_frame_box);
    auto r_separator = Gtk::make_managed<Gtk::Separator>();

    auto p_after = Gtk::make_managed<Gtk::CheckButton>("after");
    p_after->signal_toggled().connect([this, p_after] () { if (p_after->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode after"); });
    auto p_before = Gtk::make_managed<Gtk::CheckButton>("before");
    p_before->signal_toggled().connect([this, p_before] () { if (p_before->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode before"); });
    auto p_beginning = Gtk::make_managed<Gtk::CheckButton>("beginning");
    p_beginning->signal_toggled().connect([this, p_beginning] () { if (p_beginning->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode beginning"); });
    auto p_end = Gtk::make_managed<Gtk::CheckButton>("end");
    p_end->signal_toggled().connect([this, p_end] () { if (p_end->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode end"); });
    p_before->set_group(*p_after);
    p_beginning->set_group(*p_after);
    p_end->set_group(*p_after);
    auto p_frame = Gtk::make_managed<Gtk::Frame>("Position");
    auto p_frame_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    p_frame_box->append(*p_after);
    p_frame_box->append(*p_before);
    p_frame_box->append(*p_beginning);
    p_frame_box->append(*p_end);
    p_frame->set_child(*p_frame_box);
    auto p_separator = Gtk::make_managed<Gtk::Separator>();

    auto f_frame = Gtk::make_managed<Gtk::Frame>("Focus");
    auto f_frame_box = Gtk::make_managed<Gtk::Box>();
    auto f_focus = Gtk::make_managed<Gtk::CheckButton>("focus");
    f_focus->signal_toggled().connect([this, f_focus]() { if (f_focus->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode focus"); });
    auto f_nofocus = Gtk::make_managed<Gtk::CheckButton>("nofocus");
    f_nofocus->set_group(*f_focus);
    f_nofocus->signal_toggled().connect([this, f_nofocus]() { if (f_nofocus->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode nofocus"); });
    f_frame_box->append(*f_focus);
    f_frame_box->append(*f_nofocus);
    f_frame->set_child(*f_frame_box);
    auto f_separator = Gtk::make_managed<Gtk::Separator>();

    auto a_frame = Gtk::make_managed<Gtk::Frame>("Reorder");
    auto a_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    auto a_manual = Gtk::make_managed<Gtk::CheckButton>("noauto"); 
    a_manual->signal_toggled().connect([this, a_manual] () { if (a_manual->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode noreorder_auto"); });
    auto a_auto = Gtk::make_managed<Gtk::CheckButton>("auto");
    a_auto->set_group(*a_manual);
    a_auto->signal_toggled().connect([this, a_auto] () { if (a_auto->get_active()) ipc.send_cmd(IPC_COMMAND, "set_mode reorder_auto"); });
    a_box->append(*a_manual);
    a_box->append(*a_auto);
    a_frame->set_child(*a_box);
    auto a_separator = Gtk::make_managed<Gtk::Separator>();

    auto c_frame = Gtk::make_managed<Gtk::Frame>("Center");
    auto c_frame_box = Gtk::make_managed<Gtk::Box>();
    auto c_col = Gtk::make_managed<Gtk::CheckButton>("horizontal");
    c_col->signal_toggled().connect([this, c_col]() {
        if (c_col->get_active())
            ipc.send_cmd(IPC_COMMAND, "set_mode center_horiz");
        else
            ipc.send_cmd(IPC_COMMAND, "set_mode nocenter_horiz");
    });
    auto c_win = Gtk::make_managed<Gtk::CheckButton>("vertical");
    c_win->signal_toggled().connect([this, c_win]() {
        if (c_win->get_active())
            ipc.send_cmd(IPC_COMMAND, "set_mode center_vert");
        else
            ipc.send_cmd(IPC_COMMAND, "set_mode nocenter_vert");
    });
    c_frame_box->append(*c_col);
    c_frame_box->append(*c_win);
    c_frame->set_child(*c_frame_box);

    mode_label.add_css_class("scroller-mode");

    auto update_data = [this, r_hor, r_ver, p_after, p_before, p_beginning, p_end, f_focus, f_nofocus, a_manual, a_auto] (const ScrollIpcResponse &data) {
        if (data.type == IPC_GET_SCROLLER || data.type == IPC_EVENT_SCROLLER) {
            json json_scroller = json::parse(data.payload);
            json scroller = json_scroller["scroller"];
            if (scroller.is_null()) {
                // Workspace doesn't exist yet
                return;
            }
            overview_label.set_text(scroller["overview"].get<bool>() ? "🐦" : "");
            if (scroller["scaled"].get<bool>()) {
                scale_label.set_text(std::format("{:4.2f}", scroller["scale"].get<double>()));
            } else {
                scale_label.set_text("");
            }
            std::string mode;
            if (scroller["mode"].get<std::string>() == "horizontal") {
                mode = "-";
                r_hor->set_active(true);
            } else {
                mode = "|";
                r_ver->set_active(true);
            }
            std::string pos;
            // position
            std::string insert = scroller["insert"].get<std::string>();
            if (insert == "after") {
                pos = "→";
                p_after->set_active(true);
            } else if (insert == "before") {
                pos = "←";
                p_before->set_active(true);
            } else if (insert == "end") {
                pos = "⇥";
                p_end->set_active(true);
            } else if (insert == "beginning") {
                pos = "⇤";
                p_beginning->set_active(true);
            }
            // focus
            std::string focus;
            if (scroller["focus"].get<bool>()) {
                focus = "";
                f_focus->set_active(true);
            } else {
                focus = "";
                f_nofocus->set_active(true);
            }
            // center column/window
            std::string center_column;
            if (scroller["center_horizontal"].get<bool>()) {
                center_column = "";
            } else {
                center_column = " ";
            }
            std::string center_window;
            if (scroller["center_vertical"].get<bool>()) {
                center_window = "󰉠";
            } else {
                center_window = " ";
            }
            // auto
            std::string reorder = scroller["reorder"].get<std::string>();
            std::string auto_mode;
            if (reorder == "auto") {
                auto_mode = "🅰";
                a_auto->set_active(true);
            } else {
                auto_mode = "✋";
                a_manual->set_active(true);
            }
            mode_label.set_text(std::format("{} {} {} {} {} {}  ", mode, pos, focus, center_column, center_window, auto_mode));
        }
    };

    add_css_class("scroller");

    popover.set_parent(mode_label);

    auto pop_box = Gtk::make_managed<Gtk::Box>(Gtk::Orientation::VERTICAL);
    pop_box->append(*r_frame);
    pop_box->append(*r_separator);
    pop_box->append(*p_frame);
    pop_box->append(*p_separator);
    pop_box->append(*f_frame);
    pop_box->append(*f_separator);
    pop_box->append(*a_frame);
    pop_box->append(*a_separator);
    pop_box->append(*c_frame);
    pop_box->set_vexpand(true);
    popover.set_child(*pop_box);

    append(mode_label);
    append(overview_label);
    append(scale_label);

    ipc.signal_cmd.connect(update_data);
    ipc.signal_event.connect(update_data);
    ipc.subscribe(R"(["scroller"])");
    ipc.send_cmd(IPC_GET_SCROLLER);

    click = Gtk::GestureClick::create();
    click->set_button(1); // 0 = all, 1 = left, 2 = center, 3 = right
    click->signal_pressed().connect([this] (int n_press, double x, double y) {
        auto visible = popover.get_visible();
        if (visible)
            popover.popdown();
        else
            popover.popup();
    }, true);
    mode_label.add_controller(click);
}

\`\`\`

## scroll.h
\`\`\`

#ifndef __GTKSHELL_SCROLL__
#define __GTKSHELL_SCROLL__

#include <giomm.h>
#include <glibmm.h>
#include <gtkmm/box.h>
#include <gtkmm/label.h>
#include <gtkmm/button.h>
#include <gtkmm/eventcontrollerscroll.h>
#include <gtkmm/gestureclick.h>
#include <gtkmm/popover.h>
#include <gtkmm/adjustment.h>

#include <nlohmann/json.hpp>
using json = nlohmann::json;

#include <cstdint>
#include <thread>

#define event_mask(ev) (1u << (ev & 0x7F))

enum ipc_command_type : uint32_t {
  // i3 command types - see i3's I3_REPLY_TYPE constants
  IPC_COMMAND = 0,
  IPC_GET_WORKSPACES = 1,
  IPC_SUBSCRIBE = 2,
  IPC_GET_OUTPUTS = 3,
  IPC_GET_TREE = 4,
  IPC_GET_MARKS = 5,
  IPC_GET_BAR_CONFIG = 6,
  IPC_GET_VERSION = 7,
  IPC_GET_BINDING_MODES = 8,
  IPC_GET_CONFIG = 9,
  IPC_SEND_TICK = 10,

  // sway-specific command types
  IPC_GET_INPUTS = 100,
  IPC_GET_SEATS = 101,

  // scroll-specific command types
  IPC_GET_SCROLLER = 120,
  IPC_GET_TRAILS = 121,

  // Events sent from sway to clients. Events have the highest bits set.
  IPC_EVENT_WORKSPACE = ((1U << 31) | 0),
  IPC_EVENT_OUTPUT = ((1U << 31) | 1),
  IPC_EVENT_MODE = ((1U << 31) | 2),
  IPC_EVENT_WINDOW = ((1U << 31) | 3),
  IPC_EVENT_BARCONFIG_UPDATE = ((1U << 31) | 4),
  IPC_EVENT_BINDING = ((1U << 31) | 5),
  IPC_EVENT_SHUTDOWN = ((1U << 31) | 6),
  IPC_EVENT_TICK = ((1U << 31) | 7),

  // sway-specific event types
  IPC_EVENT_BAR_STATE_UPDATE = ((1U << 31) | 20),
  IPC_EVENT_INPUT = ((1U << 31) | 21),

  // scroll-specific event types
  IPC_EVENT_SCROLLER = ((1U << 31) | 30),
  IPC_EVENT_TRAILS = ((1U << 31) | 31),
};

typedef struct {
    uint32_t size;
    uint32_t type;
    std::string payload;
} ScrollIpcResponse;

class ScrollIpc {
public:
    ScrollIpc();
    ~ScrollIpc();

    sigc::signal<void(const ScrollIpcResponse &)> signal_event;
    sigc::signal<void(const ScrollIpcResponse &)> signal_cmd;

    void send_cmd(uint32_t type, const std::string &payload = "");
    void subscribe(const std::string &payload);

private:
    void working_thread();

    static inline const std::string ipc_magic = "i3-ipc";
    static inline const size_t ipc_header_size = ipc_magic.size() + 8;

    const std::string get_socket_path() const;
    int open(const std::string &) const;
    ScrollIpcResponse send(int fd, uint32_t type, const std::string &payload = "");
    ScrollIpcResponse recv(int fd);

    int fd;
    int fd_event;

    Glib::Dispatcher dispatcher;
    std::shared_ptr<std::thread> worker_thread;
    std::atomic<bool> working;
    std::binary_semaphore sem;
    std::mutex mtx;
    ScrollIpcResponse shared_data;
};

class ScrollSubmap : public Gtk::Label {
public:
    ScrollSubmap();
    ~ScrollSubmap() {}

    void on_event(const ScrollIpcResponse &data);

private:
    ScrollIpc ipc;
};

class ScrollWorkspaces : public Gtk::Box {
public:
    ScrollWorkspaces(const std::string &output);
    ~ScrollWorkspaces() {
        for (auto workspace : workspaces)
            delete workspace.second;
    }

    void on_event(const ScrollIpcResponse &data);
    void on_cmd(const ScrollIpcResponse &data);

private:
    void workspaces_update();

    typedef struct {
        int id;
        bool urgent;
    } Workspace;

    const std::string &output;
    int focused;
    ScrollIpc ipc;
    std::vector<std::pair<Workspace, Gtk::Button *>> workspaces;
};

class ScrollClientTitle : public Gtk::Label {
public:
    ScrollClientTitle();
    ~ScrollClientTitle() {}

    void on_event(const ScrollIpcResponse &data);

private:
    Glib::ustring generate_title(const json &container);

    ScrollIpc ipc;
    int focused;
};

class ScrollKeyboardLayout : public Gtk::Label {
public:
    ScrollKeyboardLayout();
    ~ScrollKeyboardLayout() {}

    void on_event(const ScrollIpcResponse &data);
    void on_cmd(const ScrollIpcResponse &data);

private:
    ScrollIpc ipc;
};

class ScrollTrails : public Gtk::Label {
public:
    ScrollTrails();
    ~ScrollTrails() {}

    void on_event(const ScrollIpcResponse &data);
    void on_cmd(const ScrollIpcResponse &data);

private:
    ScrollIpc ipc;
};

class ScrollScroller : public Gtk::Box {
public:
    ScrollScroller();
    ~ScrollScroller() {}

private:
    ScrollIpc ipc;
    Glib::RefPtr<Gtk::GestureClick> click;
    Glib::RefPtr<Gtk::Adjustment> auto_entry;
    Gtk::Popover popover;
    Gtk::Label mode_label;
    Gtk::Label overview_label;
    Gtk::Label scale_label;
};

#endif // __GTKSHELL_SCROLL__

\`\`\`

