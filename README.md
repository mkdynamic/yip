# Yip

Experiment writing a web application with Rack/Ruby in a functional style.

## Running

Install `forego` (which is `foreman` in Go, but works better with `rbenv`).

The released version available in `homebrew` has bugs regarding outputting stdout/err, so use the edge release for now:

```bash
go get -u github.com/ddollar/forego
```

Install gems and start the web server:

```ruby
bundle
forego start
```
