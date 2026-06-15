if (typeof Symbol === 'undefined' || typeof Symbol.iterator === 'undefined') {
    delete Array.prototype.entries;
}

if (document.fonts && document.fonts.load) {
    document.fonts.load("400 10pt Roboto", "E");
    document.fonts.load("500 10pt Roboto", "E");
}

var ytcsi = {
    gt: function (n) {
        n = (n || "") + "data_";
        return ytcsi[n] || (ytcsi[n] = { tick: {}, info: {}, gel: { preLoggedGelInfos: [] } });
    },

    now:
        window.performance &&
        window.performance.timing &&
        window.performance.now &&
        window.performance.timing.navigationStart
            ? function () {
                return window.performance.timing.navigationStart + window.performance.now();
            }
            : function () {
                return new Date().getTime();
            },

    tick: function (l, t, n) {
        var ticks = ytcsi.gt(n).tick;
        var v = t || ytcsi.now();

        if (ticks[l]) {
            ticks["_" + l] = ticks["_" + l] || [ticks[l]];
            ticks["_" + l].push(v);
        }

        ticks[l] = v;
    },

    info: function (k, v, n) {
        ytcsi.gt(n).info[k] = v;
    },

    infoGel: function (p, n) {
        ytcsi.gt(n).gel.preLoggedGelInfos.push(p);
    },

    setStart: function (t, n) {
        ytcsi.tick("_start", t, n);
    }
};

(function (w, d) {
    function isGecko() {
        if (!w.navigator) return false;

        try {
            if (
                w.navigator.userAgentData &&
                w.navigator.userAgentData.brands &&
                w.navigator.userAgentData.brands.length
            ) {
                var brands = w.navigator.userAgentData.brands;
                for (var i = 0; i < brands.length; i++) {
                    if (brands[i] && brands[i].brand === "Firefox") return true;
                }
                return false;
            }
        } catch (e) {
            setTimeout(function () {
                throw e;
            });
        }

        if (!w.navigator.userAgent) return false;

        var ua = w.navigator.userAgent;

        return (
            ua.indexOf("Gecko") > 0 &&
            ua.toLowerCase().indexOf("webkit") < 0 &&
            ua.indexOf("Edge") < 0 &&
            ua.indexOf("Trident") < 0 &&
            ua.indexOf("MSIE") < 0
        );
    }

    ytcsi.setStart(w.performance ? w.performance.timing.responseStart : null);

    var isPrerender = (d.visibilityState || d.webkitVisibilityState) === "prerender";

    var vName =
        !d.visibilityState && d.webkitVisibilityState
            ? "webkitvisibilitychange"
            : "visibilitychange";

    if (isPrerender) {
        var startTick = function () {
            ytcsi.setStart();
            d.removeEventListener(vName, startTick);
        };

        d.addEventListener(vName, startTick, false);
    }

    if (d.addEventListener) {
        d.addEventListener(
            vName,
            function () {
                ytcsi.tick("vc");
            },
            false
        );
    }

    if (isGecko()) {
        var isHidden = (d.visibilityState || d.webkitVisibilityState) === "hidden";
        if (isHidden) ytcsi.tick("vc");
    }

    var slt = function (el, t) {
        setTimeout(function () {
            var n = ytcsi.now();
            el.loadTime = n;

            if (el.slt) el.slt();
        }, t);
    };

    w.__ytRIL = function (el) {
        if (!el.getAttribute("data-thumb")) {
            if (w.requestAnimationFrame) {
                w.requestAnimationFrame(function () {
                    slt(el, 0);
                });
            } else {
                slt(el, 16);
            }
        }
    };
})(window, document);

/* ===== ytcfg ===== */
var ytcfg = {
    d: function () {
        return (window.yt && yt.config_) || ytcfg.data_ || (ytcfg.data_ = {});
    },

    get: function (k, o) {
        return k in ytcfg.d() ? ytcfg.d()[k] : o;
    },

    set: function () {
        var a = arguments;
        if (a.length > 1) {
            ytcfg.d()[a[0]] = a[1];
        } else {
            for (var k in a[0]) {
                ytcfg.d()[k] = a[0][k];
            }
        }
    }
};

ytcfg.set({
    CLIENT_CANARY_STATE: "none",
    DEVICE: "DESKTOP",
    EVENT_ID: "example_event",

    GL: "NO",
    HL: "en",

    INNERTUBE_CLIENT_NAME: "WEB_EMBEDDED_PLAYER",
    INNERTUBE_CLIENT_VERSION: "2.20260612.01.00",

    LOGGED_IN: false,
    PLAYER_CLIENT_VERSION: "1.20260609.07.00",

    VIDEO_ID: "cuCbkvvxmzQ"
});

/* ===== ready hook ===== */
window.ytAtP = new Promise(res => (window.ytAtN = res));

window.addEventListener("DOMContentLoaded", () => {
    window.ytAtN();
    delete window.ytAtN;
});

/* ===== error handler ===== */
window.yterr = window.yterr || true;
window.unhandledErrorMessages = {};

window.onerror = function (msg, url, line, column, error) {
    var err = error || new Error(msg);

    if (!error) {
        err.message = msg;
        err.fileName = url;
        err.lineNumber = line;
        if (!isNaN(column)) err.columnNumber = column;
    }

    var message = String(err.message);
    if (!err.message || message in window.unhandledErrorMessages) return;

    window.unhandledErrorMessages[message] = true;

    var img = new Image();
    window.emergencyTimeoutImg = img;

    img.onload = img.onerror = function () {
        delete window.emergencyTimeoutImg;
    };

    var values = {
        "client.name": ytcfg.get("INNERTUBE_CLIENT_NAME"),
        "client.version": ytcfg.get("INNERTUBE_CLIENT_VERSION"),
        msg: message,
        type: "UnhandledWindow" + err.name,
        file: err.fileName,
        line: err.lineNumber,
        stack: (err.stack || "").substr(0, 500)
    };

    var parts = [
        ytcfg.get("EMERGENCY_BASE_URL", "/error_204?t=jserror&level=ERROR")
    ];

    for (var key in values) {
        var value = values[key];
        if (value) {
            parts.push(key + "=" + encodeURIComponent(value));
        }
    }

    img.src = parts.join("&");
};

/* ===== global flags ===== */
var yterr = yterr || true;

window.WIZ_global_data = {
    MUE6Ne: "youtube_web",
    xwAfE: true
};
