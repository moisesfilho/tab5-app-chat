/**
 * @file main.c
 * @brief Aplicativo de Chat desacoplado para Tab5 OS (tab5-app-chat)
 *
 * Interface com um servidor OpenAI-compatible via cliente AI nativo do host.
 * O host envia um evento de poll (event_type==0, obj==0) a cada 200ms para
 * que a aplicacao consulte o estado assincrono da requisicao de IA.
 */

#include "tab5_sdk.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_MESSAGES 64
#define MAX_TEXT 640
#define MAX_CFG_TEXT 240

#define MSG_TOP 104
#define INPUT_H 60
#define INPUT_GAP 6
#define PAD_SM 8

#define AI_STATE_IDLE 0
#define AI_STATE_BUSY 1
#define AI_STATE_READY 2
#define AI_STATE_ERROR 3
#define AI_STATE_CANCELLED 4

typedef struct {
    char role[16];
    char text[MAX_TEXT];
} chat_message_t;

static chat_message_t s_messages[MAX_MESSAGES];
static int s_message_count = 0;

static tab5_ui_obj_t s_messages_cont = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_input_cont = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_input_ta = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_send_btn = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_settings_btn = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_modal = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_modal_backdrop = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_modal_card = TAB5_UI_INVALID_OBJ;

static tab5_ai_config_t s_cfg;
static int s_last_kb_h = -1;
static int s_last_w = -1;
static int s_last_h = -1;
static bool s_thinking_added = false;
static bool s_ui_ready = false;

static bool s_modal_open = false;
static tab5_ui_obj_t s_cfg_url = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_cfg_token = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_cfg_model = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_cfg_max_tokens = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_btn_save = TAB5_UI_INVALID_OBJ;
static tab5_ui_obj_t s_btn_cancel_cfg = TAB5_UI_INVALID_OBJ;

static void rebuild_messages(void);
static void apply_layout(void);
static void apply_modal_layout(void);

static void set_send_idle(void)
{
    if (s_send_btn != TAB5_UI_INVALID_OBJ) {
        tab5_ui_label_set_text(s_send_btn, LV_SYMBOL_RIGHT);
    }
}

static void set_send_cancel(void)
{
    if (s_send_btn != TAB5_UI_INVALID_OBJ) {
        tab5_ui_label_set_text(s_send_btn, LV_SYMBOL_CLOSE);
    }
}

static void add_message(const char *role, const char *text)
{
    if (text == NULL) {
        text = "";
    }
    while (s_message_count >= MAX_MESSAGES) {
        for (int i = 1; i < s_message_count; i++) {
            s_messages[i - 1] = s_messages[i];
        }
        s_message_count--;
    }
    chat_message_t *msg = &s_messages[s_message_count++];
    strncpy(msg->role, role, sizeof(msg->role) - 1);
    msg->role[sizeof(msg->role) - 1] = '\0';
    strncpy(msg->text, text, sizeof(msg->text) - 1);
    msg->text[sizeof(msg->text) - 1] = '\0';
    rebuild_messages();
}

static void remove_last_thinking(void)
{
    if (s_message_count > 0) {
        s_message_count--;
    }
    s_thinking_added = false;
}

static void build_bubble(const chat_message_t *msg)
{
    uint32_t pal_surface = tab5_ui_theme_get_color(TAB5_UI_COLOR_SURFACE);
    uint32_t pal_accent = tab5_ui_theme_get_color(TAB5_UI_COLOR_ACCENT);
    uint32_t pal_border = tab5_ui_theme_get_color(TAB5_UI_COLOR_BORDER);
    uint32_t pal_text = tab5_ui_theme_get_color(TAB5_UI_COLOR_TEXT);
    uint32_t pal_text_muted = tab5_ui_theme_get_color(TAB5_UI_COLOR_TEXT_MUTED);

    bool is_user = (strcmp(msg->role, "user") == 0);
    bool is_system = (strcmp(msg->role, "system") == 0);

    tab5_ui_obj_t row = tab5_ui_container_create(s_messages_cont);
    tab5_ui_obj_set_scrollable(row, false);
    tab5_ui_obj_set_size(row, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_style_bg(row, 0, 0);
    tab5_ui_obj_set_style_border(row, 0, 0);
    tab5_ui_obj_set_pad(row, 2);
    tab5_ui_obj_set_gap(row, is_system ? 0 : 4);
    tab5_ui_obj_set_flex_flow(row, TAB5_UI_FLEX_FLOW_ROW);

    if (is_user || is_system) {
        tab5_ui_obj_t spacer = tab5_ui_container_create(row);
        tab5_ui_obj_set_scrollable(spacer, false);
        tab5_ui_obj_set_size(spacer, 0, 0);
        tab5_ui_obj_set_style_bg(spacer, 0, 0);
        tab5_ui_obj_set_style_border(spacer, 0, 0);
        tab5_ui_obj_set_flex_grow(spacer, 1);
        if (!is_user) {
            tab5_ui_obj_t second_spacer = tab5_ui_container_create(row);
            tab5_ui_obj_set_scrollable(second_spacer, false);
            tab5_ui_obj_set_size(second_spacer, 0, 0);
            tab5_ui_obj_set_style_bg(second_spacer, 0, 0);
            tab5_ui_obj_set_style_border(second_spacer, 0, 0);
            tab5_ui_obj_set_flex_grow(second_spacer, 1);
        }
    }

    tab5_ui_obj_t bubble = tab5_ui_container_create(row);
    tab5_ui_obj_set_scrollable(bubble, false);
    tab5_ui_obj_set_size(bubble, is_system ? TAB5_UI_PCT(100) : TAB5_UI_PCT(80), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_pad(bubble, PAD_SM);
    tab5_ui_obj_set_gap(bubble, 0);
    tab5_ui_obj_set_style_radius(bubble, 12);

    tab5_ui_obj_t lbl = tab5_ui_label_create(bubble, msg->text);
    tab5_ui_obj_set_size(lbl, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_label_set_wrap(lbl, true);

    if (is_user) {
        tab5_ui_obj_set_style_bg(bubble, pal_accent, 255);
        tab5_ui_obj_set_style_border(bubble, 0, 0);
        tab5_ui_obj_set_style_text_color(lbl, 0xFFFFFF, 255);
    } else if (is_system) {
        tab5_ui_obj_set_style_bg(bubble, pal_surface, 255);
        tab5_ui_obj_set_style_border(bubble, pal_accent, 1);
        tab5_ui_obj_set_style_text_color(lbl, pal_text_muted, 255);
    } else {
        tab5_ui_obj_set_style_bg(bubble, pal_surface, 255);
        tab5_ui_obj_set_style_border(bubble, pal_border, 1);
        tab5_ui_obj_set_style_text_color(lbl, pal_text, 255);
    }
}

static void rebuild_messages(void)
{
    if (!s_ui_ready || s_messages_cont == TAB5_UI_INVALID_OBJ) {
        return;
    }

    tab5_ui_obj_clean(s_messages_cont);
    tab5_ui_obj_set_flex_flow(s_messages_cont, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_pad(s_messages_cont, 6);
    tab5_ui_obj_set_gap(s_messages_cont, 2);

    for (int i = 0; i < s_message_count; i++) {
        build_bubble(&s_messages[i]);
    }

    tab5_ui_obj_scroll_to_bottom(s_messages_cont, true);
}

static void show_welcome_if_unconfigured(void)
{
    tab5_ai_config_load(&s_cfg);
    bool unconfigured = (s_cfg.token[0] == '\0' || s_cfg.base_url[0] == '\0' || s_cfg.model[0] == '\0');
    if (s_message_count == 0 && unconfigured) {
        add_message("system",
                    "Bem-vindo ao Chat! Toque nas configuracoes (engrenagem) para "
                    "informar o endereco do servidor, a chave de API e o modelo.");
    }
}

static void open_config_modal(void)
{
    if (s_modal_open) {
        return;
    }
    s_modal_open = true;

    uint32_t pal_surface = tab5_ui_theme_get_color(TAB5_UI_COLOR_SURFACE);
    uint32_t pal_bg = tab5_ui_theme_get_color(TAB5_UI_COLOR_BG);
    uint32_t pal_text = tab5_ui_theme_get_color(TAB5_UI_COLOR_TEXT);
    uint32_t pal_text_muted = tab5_ui_theme_get_color(TAB5_UI_COLOR_TEXT_MUTED);
    uint32_t pal_accent = tab5_ui_theme_get_color(TAB5_UI_COLOR_ACCENT);

    tab5_ui_obj_set_size(s_modal, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(s_modal, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);

    s_modal_backdrop = tab5_ui_container_create(s_modal);
    tab5_ui_obj_set_scrollable(s_modal_backdrop, false);
    tab5_ui_obj_set_size(s_modal_backdrop, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(s_modal_backdrop, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    tab5_ui_obj_set_style_bg(s_modal_backdrop, 0x000000, 170);
    tab5_ui_obj_set_style_border(s_modal_backdrop, 0, 0);
    tab5_ui_obj_set_style_radius(s_modal_backdrop, 0);
    tab5_ui_obj_set_pad(s_modal_backdrop, 0);

    s_modal_card = tab5_ui_container_create(s_modal);
    /* Contract shape: tab5_ui_obj_set_size(xxs_modal_card, TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT)). */
    tab5_ui_obj_set_size(s_modal_card, TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_align(s_modal_card, TAB5_UI_ALIGN_CENTER, 0, 0);
    tab5_ui_obj_set_style_bg(s_modal_card, pal_surface, 255);
    tab5_ui_obj_set_style_border(s_modal_card, pal_text_muted, 1);
    tab5_ui_obj_set_style_radius(s_modal_card, 14);
    tab5_ui_obj_set_pad(s_modal_card, 16);
    tab5_ui_obj_set_gap(s_modal_card, 10);
    tab5_ui_obj_set_flex_flow(s_modal_card, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_scrollable(s_modal_card, false);

    tab5_ui_obj_t card = s_modal_card;
    tab5_ui_obj_t title = tab5_ui_label_create(card, "Configuracoes do Chat");
    tab5_ui_obj_set_size(title, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_style_text_color(title, pal_accent, 255);

    tab5_ui_obj_t cfg_body = tab5_ui_container_create(card);
    tab5_ui_obj_set_size(cfg_body, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(cfg_body, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_gap(cfg_body, 10);
    tab5_ui_obj_set_scrollable(cfg_body, false);

    tab5_ui_obj_t lbl_url;
    tab5_ui_obj_t lbl_token;
    tab5_ui_obj_t lbl_model;
    tab5_ui_obj_t lbl_tokens;

    tab5_ui_obj_t row1 = tab5_ui_container_create(cfg_body);
    tab5_ui_obj_set_size(row1, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(row1, TAB5_UI_FLEX_FLOW_ROW);
    /* PCT(50) + PCT(50) must fit exactly; the row gap is vertical only. */
    tab5_ui_obj_set_gap(row1, 0);
    tab5_ui_obj_set_scrollable(row1, false);

    tab5_ui_obj_t row2 = tab5_ui_container_create(cfg_body);
    tab5_ui_obj_set_size(row2, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(row2, TAB5_UI_FLEX_FLOW_ROW);
    /* Keep both columns fully usable without horizontal overflow. */
    tab5_ui_obj_set_gap(row2, 0);
    tab5_ui_obj_set_scrollable(row2, false);

    tab5_ui_obj_t cell_url = tab5_ui_container_create(row1);
    tab5_ui_obj_set_size(cell_url, TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(cell_url, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_gap(cell_url, 4);
    tab5_ui_obj_set_scrollable(cell_url, false);
    /* lbl_url = tab5_ui_label_create(cell_url) — label owned by the cell. */
    lbl_url = tab5_ui_label_create(cell_url, "Base URL");
    tab5_ui_obj_set_size(lbl_url, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_style_text_color(lbl_url, pal_text_muted, 255);
    s_cfg_url = tab5_ui_textarea_create(cell_url);
    tab5_ui_obj_set_scrollable(s_cfg_url, false);
    tab5_ui_obj_set_size(s_cfg_url, TAB5_UI_PCT(100), 42);
    tab5_ui_textarea_set_text(s_cfg_url, s_cfg.base_url);
    tab5_ui_textarea_set_placeholder(s_cfg_url, "https://exemplo:8080/v1");
    tab5_ui_textarea_set_cursor_pos(s_cfg_url, TAB5_UI_CURSOR_LAST);

    tab5_ui_obj_t cell_token = tab5_ui_container_create(row1);
    tab5_ui_obj_set_size(cell_token, TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(cell_token, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_gap(cell_token, 4);
    tab5_ui_obj_set_scrollable(cell_token, false);
    /* lbl_token = tab5_ui_label_create(cell_token) — label owned by the cell. */
    lbl_token = tab5_ui_label_create(cell_token, "Token");
    tab5_ui_obj_set_size(lbl_token, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_style_text_color(lbl_token, pal_text_muted, 255);
    s_cfg_token = tab5_ui_textarea_create(cell_token);
    tab5_ui_obj_set_scrollable(s_cfg_token, false);
    tab5_ui_obj_set_size(s_cfg_token, TAB5_UI_PCT(100), 42);
    tab5_ui_textarea_set_text(s_cfg_token, s_cfg.token);
    tab5_ui_textarea_set_placeholder(s_cfg_token, "sk-...");
    tab5_ui_textarea_set_password_mode(s_cfg_token, true);
    tab5_ui_textarea_set_cursor_pos(s_cfg_token, TAB5_UI_CURSOR_LAST);

    tab5_ui_obj_t cell_model = tab5_ui_container_create(row2);
    tab5_ui_obj_set_size(cell_model, TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(cell_model, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_gap(cell_model, 4);
    tab5_ui_obj_set_scrollable(cell_model, false);
    /* lbl_model = tab5_ui_label_create(cell_model) — label owned by the cell. */
    lbl_model = tab5_ui_label_create(cell_model, "Modelo");
    tab5_ui_obj_set_size(lbl_model, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_style_text_color(lbl_model, pal_text_muted, 255);
    s_cfg_model = tab5_ui_textarea_create(cell_model);
    tab5_ui_obj_set_scrollable(s_cfg_model, false);
    tab5_ui_obj_set_size(s_cfg_model, TAB5_UI_PCT(100), 42);
    tab5_ui_textarea_set_text(s_cfg_model, s_cfg.model);
    tab5_ui_textarea_set_placeholder(s_cfg_model, "deepseek-v4-pro");
    tab5_ui_textarea_set_cursor_pos(s_cfg_model, TAB5_UI_CURSOR_LAST);

    tab5_ui_obj_t cell_max_tokens = tab5_ui_container_create(row2);
    tab5_ui_obj_set_size(cell_max_tokens, TAB5_UI_PCT(50), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_flex_flow(cell_max_tokens, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_gap(cell_max_tokens, 4);
    tab5_ui_obj_set_scrollable(cell_max_tokens, false);
    /* lbl_tokens = tab5_ui_label_create(cell_max_tokens) — label owned by the cell. */
    lbl_tokens = tab5_ui_label_create(cell_max_tokens, "Max tokens");
    tab5_ui_obj_set_size(lbl_tokens, TAB5_UI_PCT(100), TAB5_UI_SIZE_CONTENT);
    tab5_ui_obj_set_style_text_color(lbl_tokens, pal_text_muted, 255);
    s_cfg_max_tokens = tab5_ui_textarea_create(cell_max_tokens);
    tab5_ui_obj_set_scrollable(s_cfg_max_tokens, false);
    tab5_ui_obj_set_size(s_cfg_max_tokens, TAB5_UI_PCT(100), 42);
    char tok_buf[16];
    snprintf(tok_buf, sizeof(tok_buf), "%d", s_cfg.max_tokens > 0 ? s_cfg.max_tokens : 4000);
    tab5_ui_textarea_set_text(s_cfg_max_tokens, tok_buf);
    tab5_ui_textarea_set_placeholder(s_cfg_max_tokens, "4000");
    tab5_ui_textarea_set_cursor_pos(s_cfg_max_tokens, TAB5_UI_CURSOR_LAST);

    tab5_ui_obj_t btns = tab5_ui_container_create(card);
    tab5_ui_obj_set_scrollable(btns, false);
    tab5_ui_obj_set_size(btns, TAB5_UI_PCT(100), 48);
    tab5_ui_obj_set_style_bg(btns, 0, 0);
    tab5_ui_obj_set_style_border(btns, 0, 0);
    tab5_ui_obj_set_pad(btns, 0);
    /* Two PCT(50) action buttons also require zero horizontal gap. */
    tab5_ui_obj_set_gap(btns, 0);
    tab5_ui_obj_set_flex_flow(btns, TAB5_UI_FLEX_FLOW_ROW);

    s_btn_cancel_cfg = tab5_ui_btn_create(btns, "Cancelar");
    tab5_ui_obj_set_size(s_btn_cancel_cfg, TAB5_UI_PCT(50), 44);
    tab5_ui_obj_set_style_bg(s_btn_cancel_cfg, pal_bg, 255);
    tab5_ui_obj_set_style_text_color(s_btn_cancel_cfg, pal_text, 255);

    s_btn_save = tab5_ui_btn_create(btns, "Salvar");
    tab5_ui_obj_set_size(s_btn_save, TAB5_UI_PCT(50), 44);
    tab5_ui_obj_set_style_bg(s_btn_save, pal_accent, 255);
    tab5_ui_obj_set_style_text_color(s_btn_save, 0xFFFFFF, 255);

    apply_modal_layout();
}

/* Keep the modal in the visible part of the display while preserving its
 * children.  The negative center offset moves the card's center above the
 * keyboard, rather than destroying and recreating the textareas. */
static void apply_modal_layout(void)
{
    if (!s_ui_ready || !s_modal_open || s_modal == TAB5_UI_INVALID_OBJ) {
        return;
    }

    int32_t kb_h = tab5_ui_keyboard_get_height();
    if (kb_h < 0) kb_h = 0;

    tab5_ui_obj_set_size(s_modal, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
    tab5_ui_obj_set_align(s_modal, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    if (s_modal_backdrop != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_t backdrop = s_modal_backdrop;
        tab5_ui_obj_set_size(backdrop, TAB5_UI_PCT(100), TAB5_UI_PCT(100));
        tab5_ui_obj_set_align(backdrop, TAB5_UI_ALIGN_TOP_LEFT, 0, 0);
    }
    if (s_modal_card != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_t card = s_modal_card;
        /* Contract shape: tab5_ui_obj_set_size(xxs_modal_card, TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT)). */
        tab5_ui_obj_set_size(card, TAB5_UI_PCT(96), TAB5_UI_SIZE_CONTENT);
        tab5_ui_obj_set_align(card, TAB5_UI_ALIGN_CENTER, 0, -(kb_h / 2));
    }
}

static void close_config_modal(void)
{
    if (!s_modal_open) {
        return;
    }
    s_modal_open = false;
    tab5_ui_obj_clean(s_modal);
    tab5_ui_obj_set_size(s_modal, 0, 0);
    s_modal_backdrop = TAB5_UI_INVALID_OBJ;
    s_modal_card = TAB5_UI_INVALID_OBJ;
    s_cfg_url = TAB5_UI_INVALID_OBJ;
    s_cfg_token = TAB5_UI_INVALID_OBJ;
    s_cfg_model = TAB5_UI_INVALID_OBJ;
    s_cfg_max_tokens = TAB5_UI_INVALID_OBJ;
    s_btn_save = TAB5_UI_INVALID_OBJ;
    s_btn_cancel_cfg = TAB5_UI_INVALID_OBJ;
    tab5_ui_keyboard_hide();
}

static void save_config_modal(void)
{
    const char *url = tab5_ui_textarea_get_text(s_cfg_url);
    const char *tok = tab5_ui_textarea_get_text(s_cfg_token);
    const char *model = tab5_ui_textarea_get_text(s_cfg_model);
    const char *tok_str = tab5_ui_textarea_get_text(s_cfg_max_tokens);

    memset(&s_cfg, 0, sizeof(s_cfg));
    if (url != NULL && url[0] != '\0') {
        strncpy(s_cfg.base_url, url, sizeof(s_cfg.base_url) - 1);
    }
    if (tok != NULL && tok[0] != '\0') {
        strncpy(s_cfg.token, tok, sizeof(s_cfg.token) - 1);
    }
    if (model != NULL && model[0] != '\0') {
        strncpy(s_cfg.model, model, sizeof(s_cfg.model) - 1);
    }
    if (tok_str != NULL && tok_str[0] != '\0') {
        int val = atoi(tok_str);
        if (val > 0) {
            s_cfg.max_tokens = val;
        } else {
            s_cfg.max_tokens = 4000;
        }
    } else {
        s_cfg.max_tokens = 4000;
    }

    tab5_ai_config_save(&s_cfg);
    close_config_modal();
    tab5_ui_show_toast("Configuracoes salvas", 1200);
    tab5_sound_play_beep(1400, 30);
    show_welcome_if_unconfigured();
}

static void do_send(void)
{
    if (s_input_ta == TAB5_UI_INVALID_OBJ) {
        return;
    }
    const char *text = tab5_ui_textarea_get_text(s_input_ta);
    if (text == NULL || text[0] == '\0') {
        tab5_sound_play_beep(300, 40);
        return;
    }

    tab5_ai_config_load(&s_cfg);
    if (s_cfg.base_url[0] == '\0' || s_cfg.token[0] == '\0' || s_cfg.model[0] == '\0') {
        tab5_ui_show_toast("Configure o Chat primeiro", 1500);
        open_config_modal();
        return;
    }

    add_message("user", text);
    tab5_ui_textarea_set_text(s_input_ta, "");
    tab5_ui_keyboard_hide();

    if (tab5_ai_send(text) != TAB5_OK) {
        add_message("system", "Falha ao iniciar a requisicao.");
        return;
    }

    add_message("assistant", "Pensando...");
    s_thinking_added = true;
    set_send_cancel();
}

static void on_settings_click(void)
{
    open_config_modal();
}

static void handle_poll(void)
{
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = tab5_ui_keyboard_get_height();
    bool dimensions_changed = (w != s_last_w || h != s_last_h);
    if (kb_h != s_last_kb_h || dimensions_changed) {
        s_last_kb_h = kb_h;
        s_last_w = w;
        s_last_h = h;
        apply_layout();
        if (dimensions_changed) {
            rebuild_messages();
        }
        if (s_modal_open) {
            apply_modal_layout();
        }
    }

    int32_t state = tab5_ai_get_state();
    if (state == AI_STATE_READY) {
        const char *resp = tab5_ai_get_response();
        if (s_thinking_added) {
            remove_last_thinking();
        }
        if (resp != NULL && resp[0] != '\0') {
            add_message("assistant", resp);
        } else {
            add_message("system", "(resposta vazia)");
        }
        tab5_ai_consume_response();
        set_send_idle();
    } else if (state == AI_STATE_ERROR) {
        const char *err = tab5_ai_get_error();
        if (s_thinking_added) {
            remove_last_thinking();
        }
        add_message("system", err != NULL && err[0] != '\0' ? err : "Erro ao processar a requisicao.");
        tab5_ai_consume_response();
        set_send_idle();
        tab5_sound_play_beep(500, 60);
    } else if (state == AI_STATE_CANCELLED) {
        if (s_thinking_added) {
            remove_last_thinking();
        }
        add_message("system", "Requisicao cancelada.");
        tab5_ai_consume_response();
        set_send_idle();
    }
}

static void apply_layout(void)
{
    if (!s_ui_ready) {
        return;
    }
    int32_t w = 720, h = 1280;
    tab5_ui_get_display_size(&w, &h);
    int32_t kb_h = tab5_ui_keyboard_get_height();

    /*
     * The Tab5 can rotate the LVGL display at runtime.  Do not depend on a
     * portrait-sized absolute Y coordinate for the editor: when the device
     * is already rotated, that coordinate can be outside the visible panel.
     * The input is therefore bottom-anchored below; input_y is retained only
     * to calculate the available message viewport.
     */
    int32_t input_y = h - kb_h - INPUT_H - INPUT_GAP;
    if (input_y < MSG_TOP + 40) {
        input_y = MSG_TOP + 40;
    }
    int32_t msg_h = input_y - MSG_TOP - INPUT_GAP;

    if (s_messages_cont != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_set_size(s_messages_cont, TAB5_UI_PCT(100), msg_h > 0 ? msg_h : 200);
        tab5_ui_obj_set_align(s_messages_cont, TAB5_UI_ALIGN_TOP_LEFT, 0, MSG_TOP);
    }
    if (s_input_cont != TAB5_UI_INVALID_OBJ) {
        tab5_ui_obj_set_size(s_input_cont, TAB5_UI_PCT(100), INPUT_H);
        tab5_ui_obj_set_align(s_input_cont, TAB5_UI_ALIGN_BOTTOM_LEFT, 0, -(kb_h + INPUT_GAP));
    }
}

static void build_chat_ui(void)
{
    tab5_ui_obj_t scr = tab5_ui_get_screen();
    tab5_ui_obj_set_scrollable(scr, false);
    uint32_t pal_bg = tab5_ui_theme_get_color(TAB5_UI_COLOR_BG);
    uint32_t pal_surface = tab5_ui_theme_get_color(TAB5_UI_COLOR_SURFACE);
    uint32_t pal_border = tab5_ui_theme_get_color(TAB5_UI_COLOR_BORDER);
    uint32_t pal_accent = tab5_ui_theme_get_color(TAB5_UI_COLOR_ACCENT);
    uint32_t pal_text = tab5_ui_theme_get_color(TAB5_UI_COLOR_TEXT);

    s_messages_cont = tab5_ui_container_create(scr);
    tab5_ui_obj_set_style_bg(s_messages_cont, pal_bg, 255);
    tab5_ui_obj_set_style_border(s_messages_cont, 0, 0);
    tab5_ui_obj_set_style_radius(s_messages_cont, 0);
    tab5_ui_obj_set_pad(s_messages_cont, 6);
    tab5_ui_obj_set_gap(s_messages_cont, 2);
    tab5_ui_obj_set_flex_flow(s_messages_cont, TAB5_UI_FLEX_FLOW_COLUMN);
    tab5_ui_obj_set_scrollable(s_messages_cont, true);

    s_input_cont = tab5_ui_container_create(scr);
    tab5_ui_obj_set_scrollable(s_input_cont, false);
    tab5_ui_obj_set_style_bg(s_input_cont, pal_surface, 255);
    tab5_ui_obj_set_style_border(s_input_cont, pal_border, 1);
    tab5_ui_obj_set_style_radius(s_input_cont, 0);
    tab5_ui_obj_set_pad(s_input_cont, 6);
    tab5_ui_obj_set_gap(s_input_cont, 6);
    tab5_ui_obj_set_flex_flow(s_input_cont, TAB5_UI_FLEX_FLOW_ROW);

    s_input_ta = tab5_ui_textarea_create(s_input_cont);
    tab5_ui_obj_set_scrollable(s_input_ta, false);
    tab5_ui_obj_set_size(s_input_ta, TAB5_UI_SIZE_CONTENT, TAB5_UI_PCT(100));
    tab5_ui_obj_set_flex_grow(s_input_ta, 1);
    tab5_ui_textarea_set_placeholder(s_input_ta, "Digite sua mensagem...");
    tab5_ui_textarea_set_cursor_pos(s_input_ta, TAB5_UI_CURSOR_LAST);

    s_send_btn = tab5_ui_btn_create(s_input_cont, LV_SYMBOL_RIGHT);
    tab5_ui_obj_set_size(s_send_btn, 56, TAB5_UI_PCT(100));
    tab5_ui_obj_set_style_bg(s_send_btn, pal_accent, 255);
    tab5_ui_obj_set_style_border(s_send_btn, 0, 0);
    tab5_ui_obj_set_style_radius(s_send_btn, 10);
    tab5_ui_obj_set_style_text_color(s_send_btn, 0xFFFFFF, 255);
    tab5_ui_label_set_text(s_send_btn, LV_SYMBOL_RIGHT);

    s_modal = tab5_ui_container_create(scr);
    tab5_ui_obj_set_scrollable(s_modal, false);
    tab5_ui_obj_set_style_bg(s_modal, 0, 0);
    tab5_ui_obj_set_style_border(s_modal, 0, 0);
    tab5_ui_obj_set_style_radius(s_modal, 0);
    tab5_ui_obj_set_pad(s_modal, 0);
    tab5_ui_obj_set_size(s_modal, 0, 0);

    (void)pal_text;
    (void)pal_bg;
    s_ui_ready = true;
    apply_layout();
}

static void rebuild_all(void)
{
    s_ui_ready = false;
    rebuild_messages();
    s_ui_ready = true;
    apply_layout();
}

static void app_init(void)
{
    tab5_system_log(2, "tab5_chat", "Aplicativo Chat desacoplado iniciado");
    tab5_ui_app_bar_set_title("Chat");

    memset(&s_cfg, 0, sizeof(s_cfg));
    tab5_ai_config_load(&s_cfg);

    s_settings_btn = tab5_ui_app_bar_add_action_button(LV_SYMBOL_SETTINGS, NULL, NULL);

    build_chat_ui();
    s_last_kb_h = tab5_ui_keyboard_get_height();
    tab5_ui_get_display_size(&s_last_w, &s_last_h);
    apply_layout();

    s_ui_ready = true;
    show_welcome_if_unconfigured();

    int32_t state = tab5_ai_get_state();
    if (state == AI_STATE_BUSY) {
        add_message("assistant", "Pensando...");
        s_thinking_added = true;
        set_send_cancel();
    }
}

static void app_resume(void)
{
    tab5_system_log(2, "tab5_chat", "Chat retomado");
}

static void app_pause(void)
{
    tab5_system_log(2, "tab5_chat", "Chat pausado");
}

static void app_destroy(void)
{
    tab5_system_log(2, "tab5_chat", "Chat finalizado");
    s_modal_open = false;
    s_cfg_url = TAB5_UI_INVALID_OBJ;
    s_cfg_token = TAB5_UI_INVALID_OBJ;
    s_cfg_model = TAB5_UI_INVALID_OBJ;
    s_cfg_max_tokens = TAB5_UI_INVALID_OBJ;
    s_btn_save = TAB5_UI_INVALID_OBJ;
    s_btn_cancel_cfg = TAB5_UI_INVALID_OBJ;
    s_modal_backdrop = TAB5_UI_INVALID_OBJ;
    s_modal_card = TAB5_UI_INVALID_OBJ;
    s_modal = TAB5_UI_INVALID_OBJ;
}

static void app_on_theme_changed(void)
{
    bool was_modal = s_modal_open;
    s_modal_open = false;
    s_ui_ready = false;
    tab5_ui_clear_content();
    s_messages_cont = TAB5_UI_INVALID_OBJ;
    s_input_cont = TAB5_UI_INVALID_OBJ;
    s_input_ta = TAB5_UI_INVALID_OBJ;
    s_send_btn = TAB5_UI_INVALID_OBJ;
    s_modal = TAB5_UI_INVALID_OBJ;
    s_modal_backdrop = TAB5_UI_INVALID_OBJ;
    s_modal_card = TAB5_UI_INVALID_OBJ;
    s_cfg_url = TAB5_UI_INVALID_OBJ;
    s_cfg_token = TAB5_UI_INVALID_OBJ;
    s_cfg_model = TAB5_UI_INVALID_OBJ;
    s_cfg_max_tokens = TAB5_UI_INVALID_OBJ;
    s_btn_save = TAB5_UI_INVALID_OBJ;
    s_btn_cancel_cfg = TAB5_UI_INVALID_OBJ;

    build_chat_ui();
    rebuild_messages();
    s_ui_ready = true;
    if (was_modal) {
        open_config_modal();
        apply_modal_layout();
    }
}

static void app_register_and_start(void)
{
    tab5_lifecycle_callbacks_t cbs = {
        .on_init = app_init,
        .on_resume = app_resume,
        .on_pause = app_pause,
        .on_destroy = app_destroy,
        .on_open_file = NULL,
    };

    tab5_lifecycle_register(&cbs);
    app_init();
}

TAB5_APP_EXPORT void tab5_app_on_theme_changed(bool dark)
{
    (void)dark;
    app_on_theme_changed();
}

TAB5_APP_EXPORT void tab5_app_on_ui_event(tab5_ui_obj_t obj, uint32_t event_type, int32_t event_val)
{
    (void)event_val;

    if (event_type == 0 && obj == 0) {
        handle_poll();
        return;
    }

    if (event_type != TAB5_UI_EVENT_CLICKED) {
        return;
    }

    if (obj == s_settings_btn) {
        on_settings_click();
        return;
    }

    if (s_modal_open) {
        if (obj == s_btn_save) {
            save_config_modal();
        } else if (obj == s_btn_cancel_cfg) {
            close_config_modal();
        }
        return;
    }

    if (obj == s_send_btn) {
        if (tab5_ai_is_busy() || tab5_ai_get_state() == AI_STATE_BUSY) {
            tab5_ai_cancel();
        } else {
            do_send();
        }
    }
}

TAB5_APP_EXPORT int app_main(void)
{
    app_register_and_start();
    return 0;
}

TAB5_APP_EXPORT int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    app_register_and_start();
    return 0;
}
