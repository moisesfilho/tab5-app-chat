#ifndef TAB5_SDK_H
#define TAB5_SDK_H

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

/* Types */
typedef int tab5_ui_obj_t;
#define TAB5_UI_INVALID_OBJ (-1)
typedef int tab5_obj_t;

/* AI Config */
typedef struct {
    char base_url[256];
    char token[256];
    char model[128];
    int max_tokens;
} tab5_ai_config_t;

/* Lifecycle */
typedef struct {
    void (*on_init)(void);
    void (*on_resume)(void);
    void (*on_pause)(void);
    void (*on_destroy)(void);
    void (*on_open_file)(const char*);
} tab5_lifecycle_callbacks_t;

/* Constants */
#define TAB5_OK 0
#define TAB5_APP_EXPORT __attribute__((visibility("default")))
#define TAB5_UI_ALIGN_TOP_LEFT 0
#define TAB5_UI_ALIGN_CENTER 1
#define TAB5_UI_ALIGN_BOTTOM_LEFT 2
#define TAB5_UI_FLEX_FLOW_COLUMN 0
#define TAB5_UI_FLEX_FLOW_ROW 1
#define TAB5_UI_SIZE_CONTENT (-1)
#define TAB5_UI_EVENT_CLICKED 1
#define TAB5_UI_CURSOR_LAST (-1)
#define TAB5_UI_COLOR_BG 0
#define TAB5_UI_COLOR_SURFACE 1
#define TAB5_UI_COLOR_BORDER 2
#define TAB5_UI_COLOR_TEXT 3
#define TAB5_UI_COLOR_TEXT_MUTED 4
#define TAB5_UI_COLOR_ACCENT 5
/* Contrato real do SDK: larguras percentuais usam encoding -1000 - percent.
 * TAB5_UI_PCT(100) == -1100 (espelha tab5-os/sdk/tab5-app-sdk/include/tab5_sdk.h). */
#define TAB5_UI_PCT(percent) (-1000 - (percent))
#define LV_SYMBOL_RIGHT "\xef\x81\x94"
#define LV_SYMBOL_CLOSE "\xef\x80\x8d"
#define LV_SYMBOL_SETTINGS "\xef\x80\x93"

/* UI Functions */
static inline tab5_ui_obj_t tab5_ui_get_screen(void) { return 0; }
static inline void tab5_ui_get_display_size(int32_t *w, int32_t *h) { *w = 720; *h = 1280; }
static inline tab5_ui_obj_t tab5_ui_container_create(tab5_ui_obj_t parent) { (void)parent; return 1; }
static inline tab5_ui_obj_t tab5_ui_label_create(tab5_ui_obj_t parent, const char *text) { (void)parent; (void)text; return 2; }
static inline tab5_ui_obj_t tab5_ui_btn_create(tab5_ui_obj_t parent, const char *text) { (void)parent; (void)text; return 3; }
static inline tab5_ui_obj_t tab5_ui_textarea_create(tab5_ui_obj_t parent) { (void)parent; return 4; }
static inline void tab5_ui_obj_set_size(tab5_ui_obj_t obj, int32_t w, int32_t h) { (void)obj; (void)w; (void)h; }
static inline void tab5_ui_obj_set_align(tab5_ui_obj_t obj, int align, int32_t x, int32_t y) { (void)obj; (void)align; (void)x; (void)y; }
static inline void tab5_ui_obj_set_style_bg(tab5_ui_obj_t obj, uint32_t color, uint8_t opacity) { (void)obj; (void)color; (void)opacity; }
static inline void tab5_ui_obj_set_style_border(tab5_ui_obj_t obj, uint32_t color, uint32_t width) { (void)obj; (void)color; (void)width; }
static inline void tab5_ui_obj_set_style_radius(tab5_ui_obj_t obj, uint32_t radius) { (void)obj; (void)radius; }
static inline void tab5_ui_obj_set_style_text_color(tab5_ui_obj_t obj, uint32_t color, uint8_t opacity) { (void)obj; (void)color; (void)opacity; }
static inline void tab5_ui_obj_set_pad(tab5_ui_obj_t obj, uint32_t pad) { (void)obj; (void)pad; }
static inline void tab5_ui_obj_set_gap(tab5_ui_obj_t obj, uint32_t gap) { (void)obj; (void)gap; }
static inline void tab5_ui_obj_set_flex_flow(tab5_ui_obj_t obj, int flow) { (void)obj; (void)flow; }
static inline void tab5_ui_obj_set_flex_grow(tab5_ui_obj_t obj, uint8_t grow) { (void)obj; (void)grow; }
static inline void tab5_ui_obj_clean(tab5_ui_obj_t obj) { (void)obj; }
static inline void tab5_ui_obj_scroll_to_bottom(tab5_ui_obj_t obj, bool anim) { (void)obj; (void)anim; }
static inline void tab5_ui_obj_set_scrollable(tab5_ui_obj_t obj, bool scrollable) { (void)obj; (void)scrollable; }
static inline void tab5_ui_label_set_text(tab5_ui_obj_t obj, const char *text) { (void)obj; (void)text; }
static inline void tab5_ui_label_set_wrap(tab5_ui_obj_t obj, bool wrap) { (void)obj; (void)wrap; }
static inline void tab5_ui_textarea_set_text(tab5_ui_obj_t obj, const char *text) { (void)obj; (void)text; }
static inline void tab5_ui_textarea_set_placeholder(tab5_ui_obj_t obj, const char *text) { (void)obj; (void)text; }
static inline void tab5_ui_textarea_set_cursor_pos(tab5_ui_obj_t obj, int32_t pos) { (void)obj; (void)pos; }
static inline void tab5_ui_textarea_set_password_mode(tab5_ui_obj_t obj, bool mode) { (void)obj; (void)mode; }
static inline int32_t tab5_ui_textarea_copy_text(tab5_ui_obj_t obj, char *buffer, uint32_t capacity) {
    (void)obj;
    if (buffer != NULL && capacity > 0) {
        buffer[0] = '\0';
    }
    return 0;
}
static inline uint32_t tab5_ui_theme_get_color(int color_id) { (void)color_id; return 0; }
static inline void tab5_ui_show_toast(const char *text, int duration) { (void)text; (void)duration; }
static inline int32_t tab5_ui_keyboard_get_height(void) { return 0; }
static inline void tab5_ui_keyboard_hide(void) {}
static inline tab5_ui_obj_t tab5_ui_app_bar_add_action_button(const char *icon, void *cb, void *data) { (void)icon; (void)cb; (void)data; return 5; }
static inline void tab5_ui_app_bar_set_title(const char *title) { (void)title; }
static inline void tab5_ui_clear_content(void) {}

/* AI Functions */
static inline void tab5_ai_config_load(tab5_ai_config_t *cfg) { (void)cfg; }
static inline void tab5_ai_config_save(const tab5_ai_config_t *cfg) { (void)cfg; }
static inline int tab5_ai_send(const char *text) { (void)text; return TAB5_OK; }
static inline int tab5_ai_get_state(void) { return 0; }
static inline const char* tab5_ai_get_response(void) { return ""; }
static inline const char* tab5_ai_get_error(void) { return ""; }
static inline void tab5_ai_consume_response(void) {}
static inline bool tab5_ai_is_busy(void) { return false; }
static inline void tab5_ai_cancel(void) {}

/* System Functions */
static inline void tab5_system_log(int level, const char *tag, const char *msg) { (void)level; (void)tag; (void)msg; }
static inline void tab5_sound_play_beep(uint32_t freq, uint32_t duration) { (void)freq; (void)duration; }

/* Lifecycle */
static inline void tab5_lifecycle_register(const tab5_lifecycle_callbacks_t *cbs) { (void)cbs; }

#endif /* TAB5_SDK_H */
