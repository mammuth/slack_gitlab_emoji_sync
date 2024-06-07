FROM elixir:1.16.3-otp-26-alpine

WORKDIR /app

COPY mix.exs mix.lock ./

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

COPY . .

RUN mix compile

CMD ["mix", "run"]