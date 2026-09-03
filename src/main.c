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

static void app_init(void)
{
    tab5_system_log(2, "tab5_chat", "Aplicativo Chat IA iniciado");
    tab5_ui_app_bar_set_title("Chat IA");

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
