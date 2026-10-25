#include "school_webview.h"

#include <webkit2/webkit2.h>
#include <cmath>
#include <cstring>

namespace {

bool school_url(const char* value) {
  g_autoptr(GUri) uri = g_uri_parse(value, G_URI_FLAGS_NONE, nullptr);
  if (!uri || g_strcmp0(g_uri_get_scheme(uri), "https") != 0) return false;
  const char* host = g_uri_get_host(uri);
  return host && (g_strcmp0(host, "bit.edu.cn") == 0 ||
                  g_str_has_suffix(host, ".bit.edu.cn"));
}

void success(FlMethodCall* call, FlValue* value = nullptr) {
  fl_method_call_respond_success(call, value, nullptr);
}

void failure(FlMethodCall* call, const char* message) {
  fl_method_call_respond_error(call, "school_browser", message, nullptr, nullptr);
}

class SchoolWebview {
 public:
  SchoolWebview(FlView* view, GtkOverlay* overlay) : view_(view), overlay_(overlay) {
    g_signal_connect(overlay_, "get-child-position", G_CALLBACK(+[](
        GtkOverlay*, GtkWidget* child, GdkRectangle* allocation, gpointer data) -> gboolean {
      auto* self = static_cast<SchoolWebview*>(data);
      if (child != GTK_WIDGET(self->web_)) return FALSE;
      *allocation = self->bounds_;
      return TRUE;
    }), this);
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    channel_ = fl_method_channel_new(
        fl_engine_get_binary_messenger(fl_view_get_engine(view)),
        "dev.so1ve.bitree/school_browser", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(
        channel_, [](FlMethodChannel*, FlMethodCall* call, gpointer data) {
          static_cast<SchoolWebview*>(data)->Handle(call);
        }, this, nullptr);
  }

  ~SchoolWebview() {
    g_signal_handlers_disconnect_by_data(overlay_, this);
    Close();
    fl_method_channel_set_method_call_handler(channel_, nullptr, nullptr, nullptr);
    g_object_unref(channel_);
  }

 private:
  FlView* view_;
  GtkOverlay* overlay_;
  GdkRectangle bounds_ = {0, 0, 1, 1};
  WebKitWebView* web_ = nullptr;
  GCancellable* cancellable_ = nullptr;
  FlMethodChannel* channel_;

  void Emit(const char* name, FlValue* value) {
    fl_method_channel_invoke_method(channel_, name, value, nullptr, nullptr, nullptr);
  }

  void Close() {
    if (cancellable_) {
      g_cancellable_cancel(cancellable_);
      g_clear_object(&cancellable_);
    }
    if (web_) {
      webkit_web_view_stop_loading(web_);
      g_signal_handlers_disconnect_by_data(web_, this);
      gtk_widget_destroy(GTK_WIDGET(web_));
      g_clear_object(&web_);
    }
  }

  void Create(const char* url, const char* user_agent) {
    Close();
    cancellable_ = g_cancellable_new();
    web_ = WEBKIT_WEB_VIEW(webkit_web_view_new());
    g_object_ref_sink(web_);
    webkit_settings_set_user_agent(webkit_web_view_get_settings(web_), user_agent);
    gtk_overlay_add_overlay(overlay_, GTK_WIDGET(web_));
    // Dart supplies the body bounds before the browser becomes visible.
    g_signal_connect(web_, "load-changed", G_CALLBACK(+[](
        WebKitWebView* web, WebKitLoadEvent event, gpointer data) {
      if (event != WEBKIT_LOAD_STARTED && event != WEBKIT_LOAD_FINISHED) return;
      const char* uri = webkit_web_view_get_uri(web);
      g_autoptr(FlValue) value = fl_value_new_string(uri ? uri : "");
      static_cast<SchoolWebview*>(data)->Emit(
          event == WEBKIT_LOAD_STARTED ? "loadStart" : "loadStop", value);
    }), this);
    g_signal_connect(web_, "notify::estimated-load-progress", G_CALLBACK(+[](
        WebKitWebView* web, GParamSpec*, gpointer data) {
      g_autoptr(FlValue) value = fl_value_new_float(
          webkit_web_view_get_estimated_load_progress(web));
      static_cast<SchoolWebview*>(data)->Emit("progress", value);
    }), this);
    g_signal_connect(web_, "load-failed", G_CALLBACK(+[](
        WebKitWebView*, WebKitLoadEvent, const char*, GError* error,
        gpointer data) -> gboolean {
      if (g_error_matches(error, WEBKIT_NETWORK_ERROR,
                          WEBKIT_NETWORK_ERROR_CANCELLED)) return FALSE;
      g_autoptr(FlValue) value = fl_value_new_string(
          "学校网页加载失败，请检查网络后重试。");
      static_cast<SchoolWebview*>(data)->Emit("error", value);
      return FALSE;
    }), this);
    g_signal_connect(web_, "decide-policy", G_CALLBACK(+[](
        WebKitWebView* web, WebKitPolicyDecision* decision,
        WebKitPolicyDecisionType type, gpointer) -> gboolean {
      if (type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION &&
          type != WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) return FALSE;
      auto* navigation = WEBKIT_NAVIGATION_POLICY_DECISION(decision);
      auto* action = webkit_navigation_policy_decision_get_navigation_action(navigation);
      auto* request = webkit_navigation_action_get_request(action);
      const char* uri = webkit_uri_request_get_uri(request);
      if (!school_url(uri)) {
        webkit_policy_decision_ignore(decision);
        return TRUE;
      }
      if (type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
        webkit_policy_decision_ignore(decision);
        webkit_web_view_load_request(web, request);
        return TRUE;
      }
      return FALSE;
    }), this);
    webkit_web_view_load_uri(web_, url);
  }

  void Handle(FlMethodCall* call) {
    const char* method = fl_method_call_get_name(call);
    FlValue* args = fl_method_call_get_args(call);
    if (strcmp(method, "create") == 0) {
      const char* url = fl_value_get_string(fl_value_lookup_string(args, "url"));
      if (!school_url(url)) return failure(call, "只允许打开学校 HTTPS 页面。");
      Create(url, fl_value_get_string(fl_value_lookup_string(args, "userAgent")));
      return success(call);
    }
    if (strcmp(method, "dispose") == 0) {
      Close();
      gtk_widget_grab_focus(GTK_WIDGET(view_));
      return success(call);
    }
    if (strcmp(method, "clearCookies") == 0) {
      auto* context = webkit_web_context_get_default();
      auto* manager = webkit_web_context_get_website_data_manager(context);
      webkit_website_data_manager_clear(
          manager, WEBKIT_WEBSITE_DATA_COOKIES, 0, nullptr,
          [](GObject* object, GAsyncResult* result, gpointer data) {
            g_autoptr(FlMethodCall) pending = FL_METHOD_CALL(data);
            g_autoptr(GError) error = nullptr;
            if (webkit_website_data_manager_clear_finish(
                    WEBKIT_WEBSITE_DATA_MANAGER(object), result, &error)) {
              success(pending);
            } else {
              failure(pending, "无法清除登录状态，请重试。");
            }
          }, g_object_ref(call));
      return;
    }
    if (strcmp(method, "restoreCookie") == 0) {
      const char* url = fl_value_get_string(fl_value_lookup_string(args, "url"));
      const char* domain = fl_value_get_string(fl_value_lookup_string(args, "domain"));
      if (!school_url(url)) return failure(call, "只允许恢复学校会话。");
      const char* host = domain[0] == '.' ? domain + 1 : domain;
      g_autofree char* domain_url = g_strdup_printf("https://%s/", host);
      if (!school_url(domain_url)) return failure(call, "只允许恢复学校会话。");
      g_autoptr(GUri) source = g_uri_parse(url, G_URI_FLAGS_NONE, nullptr);
      g_autofree char* suffix = g_strdup_printf(".%s", host);
      if (g_strcmp0(g_uri_get_host(source), host) != 0 &&
          !g_str_has_suffix(g_uri_get_host(source), suffix)) {
        return failure(call, "学校会话的 Cookie 域名不匹配。");
      }
      SoupCookie* cookie = soup_cookie_new(
          fl_value_get_string(fl_value_lookup_string(args, "name")),
          fl_value_get_string(fl_value_lookup_string(args, "value")),
          domain,
          fl_value_get_string(fl_value_lookup_string(args, "path")), -1);
      soup_cookie_set_secure(cookie,
          fl_value_get_bool(fl_value_lookup_string(args, "secure")));
      soup_cookie_set_http_only(cookie,
          fl_value_get_bool(fl_value_lookup_string(args, "httpOnly")));
      FlValue* expiry = fl_value_lookup_string(args, "expires");
      if (fl_value_get_type(expiry) != FL_VALUE_TYPE_NULL) {
        g_autoptr(GDateTime) date = g_date_time_new_from_unix_utc(fl_value_get_int(expiry));
        soup_cookie_set_expires(cookie, date);
      }
      auto* manager = webkit_web_context_get_cookie_manager(webkit_web_context_get_default());
      webkit_cookie_manager_add_cookie(manager, cookie, nullptr,
          [](GObject* object, GAsyncResult* result, gpointer data) {
            g_autoptr(FlMethodCall) pending = FL_METHOD_CALL(data);
            g_autoptr(GError) error = nullptr;
            if (webkit_cookie_manager_add_cookie_finish(
                    WEBKIT_COOKIE_MANAGER(object), result, &error)) {
              success(pending);
            } else {
              failure(pending, "无法恢复登录状态，请重试。");
            }
          }, g_object_ref(call));
      soup_cookie_free(cookie);
      return;
    }
    if (!web_) return failure(call, "请先打开学校网页。");
    if (strcmp(method, "bounds") == 0) {
      auto number = [args](const char* key) {
        return fl_value_get_float(fl_value_lookup_string(args, key));
      };
      const double sx = gtk_widget_get_allocated_width(GTK_WIDGET(view_)) /
                        number("viewWidth");
      const double sy = gtk_widget_get_allocated_height(GTK_WIDGET(view_)) /
                        number("viewHeight");
      bounds_ = {
        static_cast<int>(std::lround(number("x") * sx)),
        static_cast<int>(std::lround(number("y") * sy)),
        static_cast<int>(std::lround(number("width") * sx)),
        static_cast<int>(std::lround(number("height") * sy))
      };
      gtk_widget_queue_resize(GTK_WIDGET(overlay_));
      if (!gtk_widget_get_visible(GTK_WIDGET(web_))) {
        gtk_widget_show(GTK_WIDGET(web_));
        gtk_widget_grab_focus(GTK_WIDGET(web_));
      }
      return success(call);
    }
    if (strcmp(method, "load") == 0) {
      const char* url = fl_value_get_string(args);
      if (!school_url(url)) return failure(call, "只允许打开学校 HTTPS 页面。");
      webkit_web_view_load_uri(web_, url);
      return success(call);
    }
    if (strcmp(method, "cookies") == 0) {
      const char* url = fl_value_get_string(args);
      if (!school_url(url)) return failure(call, "只允许读取学校会话。");
      auto* manager = webkit_web_context_get_cookie_manager(
          webkit_web_view_get_context(web_));
      webkit_cookie_manager_get_cookies(manager, url, cancellable_,
          [](GObject* object, GAsyncResult* result, gpointer data) {
            g_autoptr(FlMethodCall) pending = FL_METHOD_CALL(data);
            g_autoptr(GError) error = nullptr;
            GList* cookies = webkit_cookie_manager_get_cookies_finish(
                WEBKIT_COOKIE_MANAGER(object), result, &error);
            if (error) return failure(pending, "无法读取登录状态，请重试。");
            g_autoptr(FlValue) values = fl_value_new_list();
            for (auto* item = cookies; item; item = item->next) {
              auto* cookie = static_cast<SoupCookie*>(item->data);
              g_autoptr(FlValue) row = fl_value_new_map();
              fl_value_set_string_take(row, "name", fl_value_new_string(soup_cookie_get_name(cookie)));
              fl_value_set_string_take(row, "value", fl_value_new_string(soup_cookie_get_value(cookie)));
              fl_value_set_string_take(row, "domain", fl_value_new_string(soup_cookie_get_domain(cookie)));
              fl_value_set_string_take(row, "path", fl_value_new_string(soup_cookie_get_path(cookie)));
              fl_value_set_string_take(row, "secure", fl_value_new_bool(soup_cookie_get_secure(cookie)));
              fl_value_set_string_take(row, "httpOnly", fl_value_new_bool(soup_cookie_get_http_only(cookie)));
              auto* expires = soup_cookie_get_expires(cookie);
              if (expires) fl_value_set_string_take(row, "expires",
                  fl_value_new_int(g_date_time_to_unix(expires)));
              fl_value_append(values, row);
            }
            g_list_free_full(cookies, reinterpret_cast<GDestroyNotify>(soup_cookie_free));
            success(pending, values);
          }, g_object_ref(call));
      return;
    }
    if (strcmp(method, "javascript") == 0) {
      // WebKit awaits Promises returned by the function body. All data fetches
      // therefore use the page's own session, Origin, Referer and user agent.
      webkit_web_view_call_async_javascript_function(
          web_, fl_value_get_string(args), -1, nullptr, nullptr, nullptr,
          cancellable_, [](GObject* object, GAsyncResult* result, gpointer data) {
            g_autoptr(FlMethodCall) pending = FL_METHOD_CALL(data);
            g_autoptr(GError) error = nullptr;
            g_autoptr(JSCValue) value = webkit_web_view_call_async_javascript_function_finish(
                WEBKIT_WEB_VIEW(object), result, &error);
            if (error) return failure(pending, "学校网页操作失败，请等页面加载完成后重试。");
            g_autofree char* json = value ? jsc_value_to_json(value, 0) : nullptr;
            g_autoptr(FlValue) response = json ? fl_value_new_string(json) : fl_value_new_null();
            success(pending, response);
          }, g_object_ref(call));
      return;
    }
    fl_method_call_respond_not_implemented(call, nullptr);
  }
};

}  // namespace

void register_school_webview(FlView* view, GtkOverlay* overlay) {
  g_object_set_data_full(G_OBJECT(view), "school-browser",
      new SchoolWebview(view, overlay), [](gpointer value) {
        delete static_cast<SchoolWebview*>(value);
      });
}
