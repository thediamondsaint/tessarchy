/*
 * tessarchy-portal: xdg-desktop-portal backend for the file chooser
 * (org.freedesktop.impl.portal.FileChooser), drawn by the Tessa shell.
 *
 * Adapted from omalauncher's omalauncher-portal (MIT, Simon Schubert and
 * contributors). That one replaces xdg-desktop-portal because it can't run
 * under proot; Tessarchy runs on plain Arch, so this is a backend and the
 * other portals (screen sharing and so on) keep working.
 *
 * Each OpenFile/SaveFile asks the shell over Quickshell IPC:
 *   tessera-shell ipc call picker pick <reply fifo> <open|folder|save>
 *       <1|0 multiple> <folder> <name> <title> <glob;glob;...>
 * The call prints "ok" when the shell will pick: it then writes the picked
 * paths to the reply FIFO, one per line, ended by an empty line (an empty
 * line alone is a cancel). Anything else means this screen is in Desktop
 * mode, and the request goes to xdg-desktop-portal-gtk unchanged, so Desktop
 * keeps GTK's own dialog.
 */
#include <errno.h>
#include <fcntl.h>
#include <gio/gio.h>
#include <gio/gunixinputstream.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define BUS_NAME "org.freedesktop.impl.portal.desktop.tessarchy"
#define OBJECT_PATH "/org/freedesktop/portal/desktop"
#define GTK_NAME "org.freedesktop.impl.portal.desktop.gtk"
#define IFACE "org.freedesktop.impl.portal.FileChooser"

enum { RESPONSE_OK = 0, RESPONSE_CANCELLED = 1, RESPONSE_OTHER = 2 };

static GDBusConnection *bus;
static GDBusNodeInfo *request_info;
static gchar *fifo_dir;

static const gchar introspection_xml[] =
    "<node><interface name='" IFACE "'>"
    "  <method name='OpenFile'><arg type='o' name='handle' direction='in'/><arg type='s' name='app_id' direction='in'/>"
    "    <arg type='s' name='parent_window' direction='in'/><arg type='s' name='title' direction='in'/>"
    "    <arg type='a{sv}' name='options' direction='in'/><arg type='u' name='response' direction='out'/>"
    "    <arg type='a{sv}' name='results' direction='out'/></method>"
    "  <method name='SaveFile'><arg type='o' name='handle' direction='in'/><arg type='s' name='app_id' direction='in'/>"
    "    <arg type='s' name='parent_window' direction='in'/><arg type='s' name='title' direction='in'/>"
    "    <arg type='a{sv}' name='options' direction='in'/><arg type='u' name='response' direction='out'/>"
    "    <arg type='a{sv}' name='results' direction='out'/></method>"
    "</interface></node>";
static const gchar request_xml[] =
    "<node><interface name='org.freedesktop.impl.portal.Request'><method name='Close'/></interface></node>";

typedef struct {
    GDBusMethodInvocation *invocation; /* NULL once answered */
    gchar *method, *handle, *fifo, *mode;
    GVariant *parameters;
    guint registration;
    gboolean forwarded;
    gint read_fd, keep_fd; /* keep_fd: our own write end, so no EOF before the shell opens it */
    GDataInputStream *lines;
    GPtrArray *picked;
    GCancellable *cancel;
} Request;

static void request_free(Request *r) {
    if (r->registration) g_dbus_connection_unregister_object(bus, r->registration);
    g_cancellable_cancel(r->cancel);
    g_clear_object(&r->cancel);
    if (r->lines) g_object_unref(r->lines); /* closes read_fd */
    else if (r->read_fd >= 0) close(r->read_fd);
    if (r->keep_fd >= 0) close(r->keep_fd);
    if (r->fifo) unlink(r->fifo);
    if (r->picked) g_ptr_array_unref(r->picked);
    g_variant_unref(r->parameters);
    g_free(r->method), g_free(r->handle), g_free(r->fifo), g_free(r->mode);
    g_free(r);
}

static gboolean answer(Request *r, guint32 response, GVariant *results) {
    if (!r->invocation) return FALSE;
    if (!results) results = g_variant_new_array(G_VARIANT_TYPE("{sv}"), NULL, 0);
    g_dbus_method_invocation_return_value(r->invocation, g_variant_new("(u@a{sv})", response, results));
    r->invocation = NULL;
    return TRUE;
}

static void finish(Request *r, guint32 response, GVariant *results) {
    answer(r, response, results);
    request_free(r);
}

/* A cancel from the shell's side is fine; Close from the portal means the app went away: tell the shell. */
static void request_call(GDBusConnection *c, const gchar *sender, const gchar *path, const gchar *iface,
                         const gchar *method, GVariant *params, GDBusMethodInvocation *invocation, gpointer data) {
    Request *r = data;
    g_dbus_method_invocation_return_value(invocation, NULL);
    if (r->forwarded) {
        g_dbus_connection_call(bus, GTK_NAME, r->handle, "org.freedesktop.impl.portal.Request", "Close", NULL, NULL,
                               G_DBUS_CALL_FLAGS_NONE, -1, NULL, NULL, NULL);
        return;
    }
    g_spawn_async(NULL, (gchar *[]){"tessera-shell", "ipc", "call", "picker", "dismiss", r->fifo, NULL}, NULL,
                  G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, NULL, NULL);
    finish(r, RESPONSE_CANCELLED, NULL);
}
static const GDBusInterfaceVTable request_vtable = {request_call, NULL, NULL, {0}};

static void forwarded(GObject *source, GAsyncResult *result, gpointer data) {
    Request *r = data;
    GError *error = NULL;
    GVariant *ret = g_dbus_connection_call_finish(bus, result, &error);
    if (ret) {
        if (r->invocation) g_dbus_method_invocation_return_value(r->invocation, ret);
        else g_variant_unref(ret);
        r->invocation = NULL;
    } else {
        g_printerr("tessarchy-portal: GTK backend: %s\n", error->message);
        g_error_free(error);
    }
    finish(r, RESPONSE_OTHER, NULL);
}

/* Desktop mode: GTK's own chooser, exactly as without this backend. */
static void forward_to_gtk(Request *r) {
    r->forwarded = TRUE;
    g_dbus_connection_call(bus, GTK_NAME, OBJECT_PATH, IFACE, r->method, g_variant_ref(r->parameters),
                           G_VARIANT_TYPE("(ua{sv})"), G_DBUS_CALL_FLAGS_NONE, G_MAXINT, NULL, forwarded, r);
}

static GVariant *results_for(Request *r) {
    GVariantBuilder results, uris;
    g_variant_builder_init(&results, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_init(&uris, G_VARIANT_TYPE_STRING_ARRAY);
    for (guint i = 0; i < r->picked->len; i++) {
        gchar *uri = g_filename_to_uri(g_ptr_array_index(r->picked, i), NULL, NULL);
        if (uri) g_variant_builder_add(&uris, "s", uri);
        g_free(uri);
    }
    g_variant_builder_add(&results, "{sv}", "uris", g_variant_builder_end(&uris));
    return g_variant_builder_end(&results);
}

static void read_line(Request *r);
static void line_read(GObject *source, GAsyncResult *result, gpointer data) {
    GError *error = NULL;
    gchar *line = g_data_input_stream_read_line_finish_utf8(G_DATA_INPUT_STREAM(source), result, NULL, &error);
    if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) { /* request already freed */
        g_error_free(error);
        return;
    }
    Request *r = data;
    if (!line || !*line) {
        g_free(line);
        g_clear_error(&error);
        if (r->picked->len > 0) finish(r, RESPONSE_OK, results_for(r));
        else finish(r, RESPONSE_CANCELLED, NULL);
        return;
    }
    if (g_path_is_absolute(line)) g_ptr_array_add(r->picked, line);
    else g_free(line);
    read_line(r);
}
static void read_line(Request *r) {
    g_data_input_stream_read_line_async(r->lines, G_PRIORITY_DEFAULT, r->cancel, line_read, r);
}

static void asked(GObject *source, GAsyncResult *result, gpointer data) {
    Request *r = data;
    gchar *out = NULL;
    GError *error = NULL;
    gboolean ran = g_subprocess_communicate_utf8_finish(G_SUBPROCESS(source), result, &out, NULL, &error);
    if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) { /* closed meanwhile; request freed */
        g_error_free(error);
        return;
    }
    if (ran && out && g_str_has_prefix(g_strstrip(out), "ok")) {
        read_line(r);
    } else {
        if (error) g_printerr("tessarchy-portal: asking the shell: %s\n", error->message);
        g_clear_error(&error);
        forward_to_gtk(r);
    }
    g_free(out);
}

static gchar *bytes_option(GVariant *options, const gchar *key) {
    /* A copy: a "^&ay" lookup points into a value g_variant_lookup has already released. */
    GVariant *value = g_variant_lookup_value(options, key, G_VARIANT_TYPE_BYTESTRING);
    if (!value) return NULL;
    gchar *text = g_variant_dup_bytestring(value, NULL);
    g_variant_unref(value);
    if (text && !*text) g_clear_pointer(&text, g_free);
    return text;
}

/* Globs of the current filter, else of the first filter: a(sa(us)), type 0 is a glob. */
static gchar *globs_option(GVariant *options) {
    GVariant *filter = NULL, *filters = NULL;
    if (!g_variant_lookup(options, "current_filter", "@(sa(us))", &filter) &&
        g_variant_lookup(options, "filters", "@a(sa(us))", &filters) && g_variant_n_children(filters) > 0)
        filter = g_variant_get_child_value(filters, 0);
    g_clear_pointer(&filters, g_variant_unref);
    GString *globs = g_string_new(NULL);
    if (filter) {
        GVariantIter *iter;
        guint32 type;
        const gchar *pattern;
        g_variant_get(filter, "(&sa(us))", NULL, &iter);
        while (g_variant_iter_loop(iter, "(u&s)", &type, &pattern))
            if (type == 0 && !strchr(pattern, ';')) g_string_append_printf(globs, "%s%s", globs->len ? ";" : "", pattern);
        g_variant_iter_free(iter);
        g_variant_unref(filter);
    }
    return g_string_free(globs, FALSE);
}

static void method_call(GDBusConnection *c, const gchar *sender, const gchar *path, const gchar *iface,
                        const gchar *method, GVariant *params, GDBusMethodInvocation *invocation, gpointer data) {
    static guint counter;
    const gchar *handle, *title;
    GVariant *options;
    g_variant_get(params, "(&o&s&s&s@a{sv})", &handle, NULL, NULL, &title, &options);
    gboolean save = g_strcmp0(method, "SaveFile") == 0;
    gboolean multiple = FALSE, directory = FALSE;
    g_variant_lookup(options, "multiple", "b", &multiple);
    g_variant_lookup(options, "directory", "b", &directory);

    Request *r = g_new0(Request, 1);
    r->invocation = invocation;
    r->method = g_strdup(method);
    r->handle = g_strdup(handle);
    r->parameters = g_variant_ref(params);
    r->read_fd = r->keep_fd = -1;
    r->cancel = g_cancellable_new();
    r->picked = g_ptr_array_new_with_free_func(g_free);
    r->mode = g_strdup(save ? "save" : directory ? "folder" : "open");
    r->registration = g_dbus_connection_register_object(bus, handle, request_info->interfaces[0], &request_vtable, r, NULL, NULL);

    gchar *folder = bytes_option(options, "current_folder");
    gchar *name = NULL;
    if (save) {
        gchar *file = bytes_option(options, "current_file");
        if (file) {
            if (!folder) folder = g_path_get_dirname(file);
            name = g_path_get_basename(file);
            g_free(file);
        }
        if (!name) g_variant_lookup(options, "current_name", "s", &name);
    }
    if (!folder) folder = g_strdup(g_get_home_dir());
    gchar *globs = globs_option(options);
    g_variant_unref(options);

    r->fifo = g_strdup_printf("%s/reply-%d-%u", fifo_dir, getpid(), ++counter);
    if (mkfifo(r->fifo, 0600) != 0 || (r->read_fd = open(r->fifo, O_RDONLY | O_NONBLOCK | O_CLOEXEC)) < 0 ||
        (r->keep_fd = open(r->fifo, O_WRONLY | O_NONBLOCK | O_CLOEXEC)) < 0) {
        g_printerr("tessarchy-portal: reply FIFO %s: %s\n", r->fifo, g_strerror(errno));
        forward_to_gtk(r);
    } else {
        r->lines = g_data_input_stream_new(g_unix_input_stream_new(r->read_fd, TRUE));
        g_object_unref(g_filter_input_stream_get_base_stream(G_FILTER_INPUT_STREAM(r->lines))); /* owned by lines */
        GError *error = NULL;
        GSubprocess *ask = g_subprocess_new(G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_SILENCE, &error,
                                            "tessera-shell", "ipc", "call", "picker", "pick", r->fifo, r->mode,
                                            multiple && !save ? "1" : "0", folder, name ? name : "", title, globs, NULL);
        if (ask) {
            g_subprocess_communicate_utf8_async(ask, NULL, r->cancel, asked, r);
            g_object_unref(ask);
        } else {
            g_printerr("tessarchy-portal: %s\n", error->message);
            g_error_free(error);
            forward_to_gtk(r);
        }
    }
    g_free(folder), g_free(name), g_free(globs);
}
static const GDBusInterfaceVTable vtable = {method_call, NULL, NULL, {0}};

static void on_bus(GDBusConnection *connection, const gchar *name, gpointer data) {
    GError *error = NULL;
    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(introspection_xml, NULL);
    if (!g_dbus_connection_register_object(connection, OBJECT_PATH, info->interfaces[0], &vtable, NULL, NULL, &error)) {
        g_printerr("tessarchy-portal: %s\n", error->message);
        exit(1);
    }
    g_dbus_node_info_unref(info);
}
static void on_lost(GDBusConnection *connection, const gchar *name, gpointer loop) {
    g_printerr("tessarchy-portal: can't own %s\n", name);
    g_main_loop_quit(loop);
}

int main(void) {
    request_info = g_dbus_node_info_new_for_xml(request_xml, NULL);
    fifo_dir = g_build_filename(g_get_user_runtime_dir(), "tessarchy-portal", NULL);
    if (g_mkdir_with_parents(fifo_dir, 0700) != 0) {
        g_printerr("tessarchy-portal: %s: %s\n", fifo_dir, g_strerror(errno));
        return 1;
    }
    GError *error = NULL;
    bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!bus) {
        g_printerr("tessarchy-portal: %s\n", error->message);
        return 1;
    }
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_bus_own_name_on_connection(bus, BUS_NAME, G_BUS_NAME_OWNER_FLAGS_NONE, NULL, on_lost, loop, NULL);
    on_bus(bus, BUS_NAME, NULL);
    g_main_loop_run(loop);
    return 1;
}
