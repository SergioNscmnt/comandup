# ComandUp

Base Rails 7.1 para o sistema de comandas com stack alinhada ao `prompt.md`:

- Ruby 3.3.x
- Rails 7.1.x
- MariaDB 11
- Redis 7
- Sidekiq 7
- Hotwire (Turbo + Stimulus)
- Bootstrap 5
- Docker Compose (`web`, `db`, `redis`, `sidekiq`)

## Subir localmente com Docker

```bash
docker compose up --build
```

Aplicação: `http://localhost:3000`
Healthcheck: `http://localhost:3000/up`
Sidekiq Web (dev): `http://localhost:3000/sidekiq`

## Variáveis de ambiente

Use `.env.example` como referência. Principais:

- `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`
- `DB_NAME_DEVELOPMENT`, `DB_NAME_TEST`, `DB_NAME_PRODUCTION`
- `REDIS_URL`, `REDIS_CACHE_URL`
- `LOG_JSON=true` para logs estruturados

## Banco de dados

`config/database.yml` está configurado para `mysql2`/MariaDB com `utf8mb4`.

## Background Jobs

- Adapter padrão: Sidekiq (`config.active_job.queue_adapter = :sidekiq`)
- Configuração Sidekiq: `config/sidekiq.yml`

## Segurança/Qualidade

- Autorização base com Pundit em `ApplicationController`
- Estrutura preparada para RSpec (`rspec-rails` no Gemfile)
