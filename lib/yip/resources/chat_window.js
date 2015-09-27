(function() {
  var $close = document.getElementsByClassName("chat-window-close")[0];
  $close.addEventListener("click", function(event) {
    event.preventDefault();
    var data = JSON.stringify({ ns: "ctrl", payload: { op: "close" } });
    parent.postMessage(data, "*");
  });

  var Chatbox = React.createClass({
    getInitialState: function() {
      return {
        data: Immutable.Map({ messages: Immutable.List() })
      };
    },
    setStateData: function(callback) {
      this.setState(function(prev) {
        prev.data = callback(prev.data);
        return prev;
      });
    },
    createMessage: function(message) {
      var payload = {
        op: "create_message",
        data: { body: message.get("body") }
      };
      var data = JSON.stringify({ ns: "ws", payload: payload });

      parent.postMessage(data, "*");
    },
    buildMessage: function(attrs) {
      var message = Immutable.Map({ body: attrs.body });

      return message;
    },
    addMessage: function(message) {
      this.setStateData(function(data) {
        return data.update('messages', function(messages) {
          return messages.push(message);
        });
      });
    },
    componentDidMount: function() {
      var that = this;

      addEventListener('message', function(event) {
        var data = event.data && JSON.parse(event.data);

        if (data.ns === "ctrl") {
          if (data.payload.op === "focus") {
            if (that.isMounted) {
              that.refs.typer.getDOMNode().focus();
            }
          }
        } else if (data.ns === 'ws') {
          if (data.payload.op === "new_message") {
            var message = that.buildMessage(data.payload.data);
            that.addMessage(message);
          }
        }
      });
    },
    handleTyperKeyup: function(event) {
      var isSubmit = event.which === 13 && !event.shiftKey;

      if (isSubmit) {
        var message = this.buildMessage({ body: event.target.value.replace(/\n+$/g, "") });
        this.addMessage(message);
        this.createMessage(message);

        event.preventDefault();
        event.target.value = "";
      }
    },
    render: function() {
      var $$messages = Immutable.List();
      var messages = this.state.data.get('messages');
      for (var idx = 0; idx < messages.size; idx++) {
        var message = messages.get(idx);
        var $message = React.createElement('div', {}, message.get('body'));
        $$messages = $$messages.push($message);
      }

      var $messages = React.createElement.apply(this, ['div', {}].concat($$messages.toArray()));
      var $typer = React.createElement('textarea', { ref: 'typer', className: 'chatbox-typer',
        onKeyUp: this.handleTyperKeyup });

      return React.createElement('div', {}, $messages, $typer);
    }
  });

  React.render(
    React.createElement(Chatbox),
    document.getElementById('chatbox-react-root')
  );
})();
