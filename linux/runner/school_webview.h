#ifndef SCHOOL_WEBVIEW_H_
#define SCHOOL_WEBVIEW_H_

#include <flutter_linux/flutter_linux.h>

// Adds the school browser to the Flutter window's overlay, never a new window.
void register_school_webview(FlView* view, GtkOverlay* overlay);

#endif
