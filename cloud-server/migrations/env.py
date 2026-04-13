# cloud-server/migrations/env.py
# Alembic migration environment — wired to LettuVault cloud settings.
# Reads DATABASE_URL from settings (not alembic.ini) so it respects
# the .env file and Render's environment variables automatically.

import sys
import os

from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy import engine_from_config
from alembic import context

# ── Make the src/ package importable ─────────────────────────────────────────
# alembic.ini lives in cloud-server/, src/ is one level down
here = os.path.dirname(os.path.abspath(__file__))          # cloud-server/migrations/
src_path = os.path.join(os.path.dirname(here), "src")      # cloud-server/src/
if src_path not in sys.path:
    sys.path.insert(0, src_path)

# ── Pull in our settings and models ──────────────────────────────────────────
from cloud_backend.core.config import settings              # noqa: E402
from cloud_backend.models.database import Base              # noqa: E402  (registers all ORM models)

# Alembic Config object (gives access to alembic.ini values)
config = context.config

# Set up loggers from alembic.ini
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Point Alembic at our live DATABASE_URL — overrides the placeholder in alembic.ini
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# Use the SQLAlchemy metadata so autogenerate can diff the schema
target_metadata = Base.metadata


# ── Offline mode (generates SQL script without a live DB connection) ──────────
def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Online mode (runs migrations against a live connection) ───────────────────
def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            # Compare server defaults so Alembic can detect type + constraint changes
            compare_type=True,
            compare_server_default=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

