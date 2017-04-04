module http.server {
    // in addition to java.base which is implicit,
    // we read these:
    requires java.logging;
    requires jdk.httpserver;

    // we
    exports fi.linuxbox.http;
}
