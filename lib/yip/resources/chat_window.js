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
        data: Immutable.Map({
          messages: Immutable.List(),
          typers: Immutable.OrderedSet()
        })
      };
    },
    setStateData: function(callback) {
      this.setState(function(prev) {
        prev.data = callback(prev.data);
        return prev;
      });
    },
    createMessage: function(message) {
      var xhr = new XMLHttpRequest;

      xhr.open("POST", "/chat_window", true);
      xhr.setRequestHeader("content-type", "application/json");
      xhr.send(JSON.stringify({ message: message.toObject() }));
    },
    createTyper: function(typer) {
      var payload = {
        op: "create_typer",
        data: { typer: typer }
      };
      var data = JSON.stringify({ ns: "ws", payload: payload });

      parent.postMessage(data, "*");
    },
    buildMessage: function(attrs) {
      var message = Immutable.Map(attrs);

      return message;
    },
    buildTyper: function(attrs) {
      var typer = Immutable.Map(attrs);

      return typer;
    },
    addMessage: function(message) {
      this.setStateData(function(data) {
        return data.update('messages', function(messages) {
          return messages.push(message);
        });
      });
    },
    addTyper: function(typer) {
      this.setStateData(function(data) {
        return data.update('typers', function(typers) {
          return typers.add(typer);
        });
      });
    },
    removeTyper: function(typer) {
      this.setStateData(function(data) {
        return data.update('typers', function(typers) {
          return typers.delete(typer);
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
          if (data.payload.op === "create_message") {
            var message = that.buildMessage(data.payload.data.message);
            that.addMessage(message);
          } else if (data.payload.op === 'create_typer') {
            var typer = that.buildTyper(data.payload.data.typer);
            that.addTyper(typer);
            setTimeout(that.removeTyper.bind(that, typer), 1000);
          }
        }
      });
    },
    handleTyperKeyup: function(event) {
      var isSubmit = event.which === 13 && !event.shiftKey;

      if (isSubmit) {
        event.preventDefault();

        var message = this.buildMessage({ body: event.target.value.replace(/\n+$/g, "") });
        this.createMessage(message);

        // this.addMessage(message);
        event.target.value = "";
      } else {
        var typer = this.buildTyper({});
        this.createTyper(typer);
      }
    },
    render: function() {
      var $messages = React.createElement('div', {},
        this.state.data.get('messages').map(function(message) {
          return React.createElement('div',
            { key: message.get('id') }, message.get('client') + ': ' + message.get('body'));
        }));

      var $typers = React.createElement('div', {},
        this.state.data.get('typers').map(function(typer) {
          return React.createElement('span',
            { key: typer.get('client') }, typer.get('client') + 'is typing');
        }));

      var $typer = React.createElement('textarea',
        { ref: 'typer', className: 'chatbox-typer', onKeyUp: this.handleTyperKeyup });

      return React.createElement('div', {}, $messages, $typer, $typers);
    }
  });

  React.render(
    React.createElement(Chatbox),
    document.getElementById('chatbox-react-root')
  );
})();
