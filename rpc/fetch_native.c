// Native fetch implementation for the rpc package, via libcurl.
//
// libcurl is the lowest-friction way to do HTTPS on every Unix-like and
// Windows host: it ships with macOS, every Linux distro, and is a one-line
// install on Windows. We do a synchronous POST and stash the result in
// process-global state for the MoonBit side to pull back.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>

#include "moonbit.h"

// Process-global result. Native MoonBit is single-threaded today; if that
// changes, lift these to thread-local.
static uint8_t *g_response_buf = NULL;
static size_t g_response_len = 0;
static char *g_error_msg = NULL;

static void clear_state(void) {
  free(g_response_buf);
  g_response_buf = NULL;
  g_response_len = 0;
  free(g_error_msg);
  g_error_msg = NULL;
}

static void set_error(const char *msg) {
  free(g_error_msg);
  g_error_msg = strdup(msg ? msg : "unknown error");
}

static size_t write_cb(void *data, size_t size, size_t nmemb, void *userp) {
  (void)userp;
  size_t add = size * nmemb;
  uint8_t *grown = realloc(g_response_buf, g_response_len + add);
  if (!grown) {
    return 0;
  }
  g_response_buf = grown;
  memcpy(g_response_buf + g_response_len, data, add);
  g_response_len += add;
  return add;
}

// POST `body` to `url_utf8` with Content-Type: application/json. On success
// the response body is captured for moonbit_curl_last_response. On failure
// the error message is captured for moonbit_curl_last_error.
//
// Returns 0 on a 2xx response, non-zero otherwise. Inputs are MoonBit
// `Bytes` values (the MoonBit side encodes the URL as UTF-8 before
// calling).
MOONBIT_EXPORT int32_t moonbit_curl_post(moonbit_bytes_t url_utf8,
                                         moonbit_bytes_t body) {
  clear_state();

  int32_t url_len = (int32_t)Moonbit_array_length(url_utf8);
  int32_t body_len = (int32_t)Moonbit_array_length(body);

  // libcurl expects a NUL-terminated URL; copy with one extra byte.
  char *url = malloc((size_t)url_len + 1);
  if (!url) {
    set_error("oom");
    return -1;
  }
  memcpy(url, url_utf8, (size_t)url_len);
  url[url_len] = '\0';

  CURL *curl = curl_easy_init();
  if (!curl) {
    set_error("curl_easy_init failed");
    free(url);
    return -2;
  }

  struct curl_slist *headers = NULL;
  headers = curl_slist_append(headers, "Content-Type: application/json");

  curl_easy_setopt(curl, CURLOPT_URL, url);
  curl_easy_setopt(curl, CURLOPT_POST, 1L);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)body_len);
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, NULL);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, "ethbit/0.0.1");
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
  // Generous timeouts for public RPC nodes; the caller can tweak later.
  curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);

  CURLcode rc = curl_easy_perform(curl);
  long http_status = 0;
  curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_status);

  curl_slist_free_all(headers);
  curl_easy_cleanup(curl);
  free(url);

  if (rc != CURLE_OK) {
    set_error(curl_easy_strerror(rc));
    return -3;
  }
  if (http_status < 200 || http_status >= 300) {
    char buf[64];
    snprintf(buf, sizeof(buf), "HTTP %ld", http_status);
    set_error(buf);
    return (int32_t)http_status;
  }
  return 0;
}

// Returns the last response body as a MoonBit Bytes (empty if there
// was no successful response).
MOONBIT_EXPORT moonbit_bytes_t moonbit_curl_last_response(void) {
  int32_t n = (int32_t)g_response_len;
  moonbit_bytes_t out = moonbit_make_bytes_raw(n);
  if (n > 0 && g_response_buf) {
    memcpy(out, g_response_buf, (size_t)n);
  }
  return out;
}

// Returns the last error message as MoonBit Bytes (UTF-8). Empty if
// the last call succeeded.
MOONBIT_EXPORT moonbit_bytes_t moonbit_curl_last_error_utf8(void) {
  int32_t n = g_error_msg ? (int32_t)strlen(g_error_msg) : 0;
  moonbit_bytes_t out = moonbit_make_bytes_raw(n);
  if (n > 0) {
    memcpy(out, g_error_msg, (size_t)n);
  }
  return out;
}
