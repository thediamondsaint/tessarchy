#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-client-protocol.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *d, struct wl_registry *r, uint32_t name, const char *interface, uint32_t version) {
    (void)d; (void)version;
    if (!strcmp(interface, "zwlr_virtual_pointer_manager_v1"))
        manager = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void removed(void *d, struct wl_registry *r, uint32_t name) { (void)d; (void)r; (void)name; }
static const struct wl_registry_listener registry_listener = {global, removed};
static int number(const char *s) {
    char *end = NULL;
    long n = strtol(s, &end, 10);
    if (!*s || *end || n < 0 || n > INT32_MAX) { fprintf(stderr, "Invalid nonnegative integer\n"); exit(2); }
    return n;
}
static uint32_t now(void) {
    struct timespec t;
    if (clock_gettime(CLOCK_MONOTONIC, &t)) { perror("clock_gettime"); exit(2); }
    return (uint32_t)((uint64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000);
}
int main(int argc, char **argv) {
    if (argc != 6 || !getenv("TESSARCHY_FIT_INPUT_PROBE") ||
        strcmp(getenv("TESSARCHY_FIT_INPUT_PROBE"), "1")) {
        fprintf(stderr, "Isolated probe only: x y width height expected_compositor_pid; guard required\n");
        return 2;
    }
    int x = number(argv[1]), y = number(argv[2]), w = number(argv[3]), h = number(argv[4]), pid = number(argv[5]);
    if (!w || !h || w > 8192 || h > 8192 || x > w || y > h || !pid) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { perror("wl_display_connect"); return 2; }
    struct ucred peer;
    socklen_t len = sizeof(peer);
    if (getsockopt(wl_display_get_fd(display), SOL_SOCKET, SO_PEERCRED, &peer, &len) ||
        peer.pid != pid || peer.uid != getuid()) {
        fprintf(stderr, "Refusing input: Wayland server credentials do not match the isolated compositor\n");
        return 2;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) return 2;
    struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    /* Force a genuine motion even when successive probes click the same pixel. */
    zwlr_virtual_pointer_v1_motion_absolute(pointer, now(), 0, 0, w, h);
    zwlr_virtual_pointer_v1_frame(pointer);
    if (wl_display_roundtrip(display) < 0) return 2;
    zwlr_virtual_pointer_v1_motion_absolute(pointer, now(), x, y, w, h);
    zwlr_virtual_pointer_v1_frame(pointer);
    if (wl_display_roundtrip(display) < 0) return 2;
    zwlr_virtual_pointer_v1_button(pointer, now(), 272, WL_POINTER_BUTTON_STATE_PRESSED);
    zwlr_virtual_pointer_v1_frame(pointer);
    zwlr_virtual_pointer_v1_button(pointer, now(), 272, WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(pointer);
    if (wl_display_roundtrip(display) < 0) return 2;
    zwlr_virtual_pointer_v1_destroy(pointer);
    zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return 0;
}
