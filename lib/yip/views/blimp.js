(function() {
  var CLASS_PREFIX = "";
  var WS_URL = "ws://localhost:9292";
  var STYLESHEET_URL = "http://localhost:9292/yip.css";
  var CHAT_WINDOW_URL = "http://localhost:9292/chat_window"

  var blimp;
  var chatWindow;
  var ws;

  var setupStylesheet = function() {
    var link = document.createElement("link");
    link.rel = "stylesheet";
    link.type = "text/css";
    link.href = STYLESHEET_URL;

    var head = document.getElementsByTagName("head")[0]
    head.appendChild(link);

    return link;
  }

  var setupBlimp = function() {
    var div = document.createElement("div")
    div.className = CLASS_PREFIX + "blimp";
    div.innerText = "?";

    var body = document.getElementsByTagName("body")[0];
    body.appendChild(div);

    return div;
  };

  var setupChatWindow = function() {
    var iframe = document.createElement("iframe");
    iframe.className = CLASS_PREFIX + "chat-window";

    var body = document.getElementsByTagName("body")[0];
    body.appendChild(iframe);

    return iframe;
  };

  var showChatWindow = function() {
    chatWindow.classList.add("is-visible");
    var data = JSON.stringify({ ns: "ctrl", payload: "focus" })
    chatWindow.contentWindow.postMessage(data, "*");
  }

  var hideChatWindow = function() {
    chatWindow.classList.remove("is-visible");
  };

  var setupWebsocket = function() {
    var ws = new WebSocket(WS_URL);

    ws.onopen = function() {
      console.log('ws open');
    };

    ws.onmessage = function(msg) {
      console.log('ws message', msg);
      chatWindow.postMessage(msg, "*");
    };

    ws.onclose = function() {
      console.log('ws close');
    };

    window.addEventListener('message', function(event) {
      var data = event.data && JSON.parse(event.data) || {};

      if (data.ns == "ws") {
        console.log('ws send', data.payload);
        ws.send(event.data);
      } else if (data.ns == "ctrl") {
        console.log('ctrl', data.payload);
        handleCtrl(data.payload);
      }
    });

    return ws;
  };

  var handleCtrl = function(payload) {
    if (payload.op === "close") {
      hideChatWindow();
    }
  };

  var boot = function() {
    setupStylesheet();
    blimp = setupBlimp();
    chatWindow = setupChatWindow();
    ws = setupWebsocket();

    chatWindow.src = CHAT_WINDOW_URL;

    blimp.addEventListener("click", function(event) {
      showChatWindow();

      // var defer = function() {
      //   var handler = function(event) {
      //     document.removeEventListener("click", handler);
      //     chatWindow.classList.remove("is-visible");
      //   };

      //   document.addEventListener("click", handler);
      // };
      // window.setTimeout(defer, 0);
    });
  };

  boot();
})();

