window.Hello = window.React.createClass({
  render: function() {
    return (
      window.React.createElement('div', {}, 'Hello from React!')
    );
  }
});

// if (mode === 'server') {
//   React.renderToString(Hello);
// } else {
//   React.render(
//     React.createElement(Hello),
//     document.getElementById('content')
//   );
// }
