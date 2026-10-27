# Contributing

Bug reports and pull requests are welcome at [github.com/jalappeno-apps/messengerr](https://github.com/jalappeno-apps/messengerr).

Read [STYLE.md](STYLE.md) first. It lists the conventions the code follows and the invariants a change must not break (never send without a preview and confirmation, one result per delivery, record results as they land, never leak a secret).

## Set up

```sh
git clone https://github.com/jalappeno-apps/messengerr
cd messengerr
bundle install
bundle exec rspec
bundle exec rubocop
```

The specs use WebMock and temporary directories: they make no real network calls and never touch your real `~/.config/messengerr`.

## Making a change

1. Write a failing spec for the behaviour you want or the bug you found.
2. Make it pass. Then revert your fix and confirm the spec fails, so you know it tests the right thing.
3. Run `bundle exec rspec` and `bundle exec rubocop`.
4. If you changed an integration or its sending options, run `bundle exec rake docs:integrations` and commit the regenerated `docs/integrations.md`.
5. If users can see the change, update the docs in `docs/` and add a line to `CHANGELOG.md`.

## Adding an integration

See [docs/writing-an-integration.md](docs/writing-an-integration.md) for the contract and the [contributing guide](docs/contributing/writing-an-integration.md) for the checklist.

## The documentation site

```sh
cd docs
bundle install
bundle exec jekyll serve --baseurl ""
```

Then open http://127.0.0.1:4000/. Only document what you have run.

## Security

Please do not open a public issue for a vulnerability. Use GitHub's private vulnerability reporting (the repository's **Security** tab, then **Report a vulnerability**).

By contributing you agree your work is released under the MIT License.
