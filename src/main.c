/**
 * @file main.c
 * @brief Aplicativo Chat / Assistente IA para Tab5 OS
 */

#include "tab5_sdk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char s_chat_history[2048] = {0};

static void append_chat_line(const char *sender, const char *msg)
{
    size_t cur_len = strlen(s_chat_history);
    char line[256];
    snprintf(line, sizeof(line), "[%s]: %s\n", sender, msg);
    size_t line_len = strlen(line);

    if (cur_len + line_len + 1 < sizeof(s_chat_history)) {
        strcat(s_chat_history, line);
    } else {
        snprintf(s_chat_history, sizeof(s_chat_history), "[...]\n[%s]: %s\n", sender, msg);
    }

    tab5_ui_obj_t ta = tab5_ui_get_main_textarea();
    if (ta != NULL) {
        tab5_ui_textarea_set_text(ta, s_chat_history);
    }
}

static void on_clear_chat(void *user_data)
{
    (void)user_data;
    s_chat_history[0] = '\0';
    append_chat_line("Sistema", "Historico de conversa limpo.");
    append_chat_line("Tab5 IA", "Ola! Como posso ajudar você hoje?");
    tab5_sound_play_beep(1000, 20);
    tab5_ui_show_toast("Conversa reiniciada", 1200);
}

static void on_send_sample_prompt(void *user_data)
{
    (void)user_data;
    append_chat_line("Voce", "Qual o resumo do sistema Tab5 OS?");
    append_chat_line("Tab5 IA", "O Tab5 OS e um sistema operacional modular baseado em FreeRTOS e LVGL9 com isolamento de apps em WebAssembly (WAMR)!");
    tab5_sound_play_beep(1400, 30);
    tab5_ui_show_toast("Resposta recebida", 1500);
}

static void app_init(void)
{
    tab5_system_log(2, "tab5_chat", "Aplicativo Chat IA iniciado");
    tab5_ui_app_bar_set_title("Chat IA");
    tab5_ui_app_bar_add_action_button("LV_SYMBOL_TRASH", on_clear_chat, NULL);
    tab5_ui_app_bar_add_action_button("LV_SYMBOL_OK", on_send_sample_prompt, NULL);

    s_chat_history[0] = '\0';
    append_chat_line("Tab5 IA", "Ola! Sou seu assistente de inteligencia artificial no Tab5 OS.");
    append_chat_line("Tab5 IA", "Pronto para responder duvidas e auxiliar em tarefas.");
}

static void app_resume(void)
{
    tab5_system_log(2, "tab5_chat", "Chat IA retomado");
}

static void app_pause(void)
{
    tab5_system_log(2, "tab5_chat", "Chat IA pausado");
}

static void app_destroy(void)
{
    tab5_system_log(2, "tab5_chat", "Chat IA finalizado");
}

TAB5_APP_EXPORT int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    tab5_lifecycle_callbacks_t cbs = {
        .on_init = app_init,
        .on_resume = app_resume,
        .on_pause = app_pause,
        .on_destroy = app_destroy,
        .on_open_file = NULL,
    };

    tab5_lifecycle_register(&cbs);
    app_init();
    return 0;
}
