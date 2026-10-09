#ifndef VOLE_H
#define VOLE_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * request_json must be a NUL-terminated UTF-8 JSON Invoke request. The
 * returned UTF-8 JSON string is independently allocated by Vole and must be
 * released with VoleFree. Invalid requests return failure JSON; NULL is
 * reserved for catastrophic allocation failure.
 */
char *VoleInvoke(const char *request_json);

/* A NULL response is ignored. Do not use the host allocator. */
void VoleFree(char *response);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* VOLE_H */
