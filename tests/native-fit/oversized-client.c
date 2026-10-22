#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"

/* Deliberately ignores a too-small configure to model an oversized native layout. */
static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct wl_seat *seat;
static struct wl_pointer *seat_pointer;
static struct wl_keyboard *seat_keyboard;
static struct wl_touch *seat_touch;
static struct xdg_wm_base *wm;
static struct wl_surface *surface;
static struct xdg_surface *xdg_surface;
static struct xdg_toplevel *toplevel;
static bool running = true;
static int minimum_width = 832, requested_width = 640, requested_height = 600;
static double pointer_x, pointer_y;

struct frame { struct wl_buffer *buffer; void *pixels; size_t length; };

static void fail(const char *what) { perror(what); exit(EXIT_FAILURE); }
static void released(void *data, struct wl_buffer *buffer) {
    struct frame *f = data;
    wl_buffer_destroy(buffer);
    munmap(f->pixels, f->length);
    free(f);
}
static const struct wl_buffer_listener buffer_listener = { .release = released };

static void render(void) {
    const int width = requested_width > minimum_width ? requested_width : minimum_width;
    const int height = requested_height > 160 ? requested_height : 160;
    struct frame *f = calloc(1, sizeof(*f));
    if (!f) fail("calloc");
    f->length = (size_t)width * (size_t)height * 4;
    int fd = memfd_create("native-fit-fixture", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, (off_t)f->length) < 0) fail("shm fd");
    f->pixels = mmap(NULL, f->length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (f->pixels == MAP_FAILED) fail("mmap");
    uint32_t *pixels = f->pixels;
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            uint32_t color = ((x * 10 / width) % 2) ? 0xff182838 : 0xff304858;
            if (y % 100 < 2) color = 0xffa0a0a0;
            if (y < 24) color = 0xffffff00;
            if (y >= height - 24) color = 0xffff00ff;
            if (x < 32) color = 0xff00ffff;
            if (x >= width - 32) color = 0xffff0000;
            pixels[(size_t)y * (size_t)width + (size_t)x] = color;
        }
    }
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int)f->length);
    f->buffer = wl_shm_pool_create_buffer(pool, 0, width, height, width * 4, WL_SHM_FORMAT_XRGB8888);
    wl_buffer_add_listener(f->buffer, &buffer_listener, f);
    wl_shm_pool_destroy(pool);
    close(fd);
    xdg_surface_set_window_geometry(xdg_surface, 0, 0, width, height);
    wl_surface_attach(surface, f->buffer, 0, 0);
    wl_surface_damage(surface, 0, 0, width, height);
    wl_surface_commit(surface);
    printf("FRAME configured=%dx%d committed=%dx%d\n", requested_width, requested_height, width, height);
}

static void configured(void *data, struct xdg_surface *s, uint32_t serial) {
    (void)data;
    xdg_surface_ack_configure(s, serial);
    render();
}
static const struct xdg_surface_listener surface_listener = { .configure = configured };
static void size_configure(void *data, struct xdg_toplevel *t, int32_t w, int32_t h, struct wl_array *states) {
    (void)data; (void)t; (void)states;
    if (w > 0) requested_width = w;
    if (h > 0) requested_height = h;
}
static void closed(void *data, struct xdg_toplevel *t) { (void)data; (void)t; running = false; }
static const struct xdg_toplevel_listener toplevel_listener = { .configure = size_configure, .close = closed };
static void ping(void *data, struct xdg_wm_base *w, uint32_t serial) { (void)data; xdg_wm_base_pong(w, serial); }
static const struct xdg_wm_base_listener wm_listener = { .ping = ping };

static void pointer_enter(void *d, struct wl_pointer *p, uint32_t serial, struct wl_surface *s, wl_fixed_t x, wl_fixed_t y) {
    (void)d; (void)p; (void)serial; (void)s;
    pointer_x = wl_fixed_to_double(x); pointer_y = wl_fixed_to_double(y);
    printf("ENTER %.3f %.3f\n", pointer_x, pointer_y);
}
static void pointer_leave(void *d, struct wl_pointer *p, uint32_t serial, struct wl_surface *s) { (void)d; (void)p; (void)serial; (void)s; }
static void pointer_motion(void *d, struct wl_pointer *p, uint32_t time, wl_fixed_t x, wl_fixed_t y) {
    (void)d; (void)p; (void)time;
    pointer_x = wl_fixed_to_double(x); pointer_y = wl_fixed_to_double(y);
    printf("MOTION %.3f %.3f\n", pointer_x, pointer_y);
}
static void pointer_button(void *d, struct wl_pointer *p, uint32_t serial, uint32_t time, uint32_t button, uint32_t state) {
    (void)d; (void)p; (void)serial; (void)time;
    printf("BUTTON %u %u %.3f %.3f\n", button, state, pointer_x, pointer_y);
}
static void pointer_axis(void *d, struct wl_pointer *p, uint32_t time, uint32_t axis, wl_fixed_t value) {
    (void)d; (void)p; (void)time;
    printf("AXIS %u %.3f\n", axis, wl_fixed_to_double(value));
}
static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter, .leave = pointer_leave, .motion = pointer_motion,
    .button = pointer_button, .axis = pointer_axis
};
static void keymap(void *d, struct wl_keyboard *k, uint32_t format, int fd, uint32_t size) { (void)d; (void)k; (void)format; (void)size; close(fd); }
static void key_enter(void *d, struct wl_keyboard *k, uint32_t serial, struct wl_surface *s, struct wl_array *keys) { (void)d; (void)k; (void)serial; (void)s; (void)keys; }
static void key_leave(void *d, struct wl_keyboard *k, uint32_t serial, struct wl_surface *s) { (void)d; (void)k; (void)serial; (void)s; }
static void key(void *d, struct wl_keyboard *k, uint32_t serial, uint32_t time, uint32_t code, uint32_t state) {
    (void)d; (void)k; (void)serial; (void)time;
    printf("KEY %u %u\n", code, state);
    if (code == 1 && state == WL_KEYBOARD_KEY_STATE_PRESSED) running = false;
}
static void modifiers(void *d, struct wl_keyboard *k, uint32_t serial, uint32_t dep, uint32_t lat, uint32_t lock, uint32_t group) {
    (void)d; (void)k; (void)serial; (void)dep; (void)lat; (void)lock; (void)group;
}
static const struct wl_keyboard_listener keyboard_listener = { .keymap = keymap, .enter = key_enter, .leave = key_leave, .key = key, .modifiers = modifiers };
static void touch_down(void *d, struct wl_touch *t, uint32_t serial, uint32_t time, struct wl_surface *s, int32_t id, wl_fixed_t x, wl_fixed_t y) {
    (void)d; (void)t; (void)serial; (void)time; (void)s;
    printf("TOUCH_DOWN %d %.3f %.3f\n", id, wl_fixed_to_double(x), wl_fixed_to_double(y));
}
static void touch_up(void *d, struct wl_touch *t, uint32_t serial, uint32_t time, int32_t id) { (void)d; (void)t; (void)serial; (void)time; printf("TOUCH_UP %d\n", id); }
static void touch_motion(void *d, struct wl_touch *t, uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y) {
    (void)d; (void)t; (void)time;
    printf("TOUCH_MOTION %d %.3f %.3f\n", id, wl_fixed_to_double(x), wl_fixed_to_double(y));
}
static void touch_frame(void *d, struct wl_touch *t) { (void)d; (void)t; }
static void touch_cancel(void *d, struct wl_touch *t) { (void)d; (void)t; puts("TOUCH_CANCEL"); }
static const struct wl_touch_listener touch_listener = { .down = touch_down, .up = touch_up, .motion = touch_motion, .frame = touch_frame, .cancel = touch_cancel };
static void capabilities(void *d, struct wl_seat *s, uint32_t caps) {
    (void)d;
    if ((caps & WL_SEAT_CAPABILITY_POINTER) && !seat_pointer) {
        seat_pointer = wl_seat_get_pointer(s);
        wl_pointer_add_listener(seat_pointer, &pointer_listener, NULL);
    } else if (!(caps & WL_SEAT_CAPABILITY_POINTER) && seat_pointer) {
        if (wl_pointer_get_version(seat_pointer) >= 3) wl_pointer_release(seat_pointer);
        else wl_pointer_destroy(seat_pointer);
        seat_pointer = NULL;
    }
    if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !seat_keyboard) {
        seat_keyboard = wl_seat_get_keyboard(s);
        wl_keyboard_add_listener(seat_keyboard, &keyboard_listener, NULL);
    } else if (!(caps & WL_SEAT_CAPABILITY_KEYBOARD) && seat_keyboard) {
        if (wl_keyboard_get_version(seat_keyboard) >= 3) wl_keyboard_release(seat_keyboard);
        else wl_keyboard_destroy(seat_keyboard);
        seat_keyboard = NULL;
    }
    if ((caps & WL_SEAT_CAPABILITY_TOUCH) && !seat_touch) {
        seat_touch = wl_seat_get_touch(s);
        wl_touch_add_listener(seat_touch, &touch_listener, NULL);
        puts("TOUCH_READY");
    } else if (!(caps & WL_SEAT_CAPABILITY_TOUCH) && seat_touch) {
        if (wl_touch_get_version(seat_touch) >= 3) wl_touch_release(seat_touch);
        else wl_touch_destroy(seat_touch);
        seat_touch = NULL;
        puts("TOUCH_REMOVED");
    }
}
static void seat_name(void *d, struct wl_seat *s, const char *name) { (void)d; (void)s; (void)name; }
static const struct wl_seat_listener seat_listener = { .capabilities = capabilities, .name = seat_name };
static void global(void *d, struct wl_registry *r, uint32_t name, const char *interface, uint32_t version) {
    (void)d;
    if (strcmp(interface, "wl_compositor") == 0) compositor = wl_registry_bind(r, name, &wl_compositor_interface, 3);
    else if (strcmp(interface, "wl_shm") == 0) shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
    else if (strcmp(interface, "xdg_wm_base") == 0) {
        wm = wl_registry_bind(r, name, &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(wm, &wm_listener, NULL);
    } else if (strcmp(interface, "wl_seat") == 0 && !seat) {
        seat = wl_registry_bind(r, name, &wl_seat_interface, version < 3 ? version : 3);
        wl_seat_add_listener(seat, &seat_listener, NULL);
    }
}
static void removed(void *d, struct wl_registry *r, uint32_t name) { (void)d; (void)r; (void)name; }
static const struct wl_registry_listener registry_listener = { .global = global, .global_remove = removed };

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (argc > 2) { fprintf(stderr, "usage: %s [minimum-width:160..4096]\n", argv[0]); return 2; }
    if (argc == 2) {
        char *end;
        errno = 0;
        long value = strtol(argv[1], &end, 10);
        if (errno || *end || !*argv[1] || value < 160 || value > 4096) { fputs("invalid minimum width\n", stderr); return 2; }
        minimum_width = (int)value;
    }
    display = wl_display_connect(NULL);
    if (!display) fail("wl_display_connect");
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    if (wl_display_roundtrip(display) < 0) fail("registry roundtrip");
    if (!compositor || !shm || !wm) { fputs("required globals unavailable\n", stderr); return 1; }
    surface = wl_compositor_create_surface(compositor);
    xdg_surface = xdg_wm_base_get_xdg_surface(wm, surface);
    xdg_surface_add_listener(xdg_surface, &surface_listener, NULL);
    toplevel = xdg_surface_get_toplevel(xdg_surface);
    xdg_toplevel_add_listener(toplevel, &toplevel_listener, NULL);
    xdg_toplevel_set_app_id(toplevel, "tessarchy-native-fit-fixture");
    xdg_toplevel_set_title(toplevel, "Native fit fixture: cyan left, red right");
    xdg_toplevel_set_min_size(toplevel, minimum_width, 160);
    wl_surface_commit(surface);
    while (running && wl_display_dispatch(display) >= 0) {}
    int error = wl_display_get_error(display);
    xdg_toplevel_destroy(toplevel);
    xdg_surface_destroy(xdg_surface);
    wl_surface_destroy(surface);
    wl_registry_destroy(registry);
    wl_display_disconnect(display);
    return error ? 1 : 0;
}
