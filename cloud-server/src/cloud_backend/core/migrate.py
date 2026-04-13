# cloud-server/src/cloud_backend/core/migrate.py
# Called once at FastAPI startup to apply any pending Alembic migrations.
# This makes every Render deploy self-healing — if the schema changed,
# it will be migrated before the first request is served.

import os
import logging

from alembic.config import Config
from alembic import command

logger = logging.getLogger(__name__)


def run_migrations() -> None:
    """
    Locate alembic.ini (two levels above this file: cloud-server/alembic.ini)
    and run `alembic upgrade head` programmatically.
    """
    # __file__  = cloud-server/src/cloud_backend/core/migrate.py
    # go up 4 levels to reach cloud-server/
    here = os.path.dirname(os.path.abspath(__file__))
    cloud_server_root = os.path.abspath(os.path.join(here, "..", "..", "..", ".."))
    alembic_ini = os.path.join(cloud_server_root, "alembic.ini")

    if not os.path.exists(alembic_ini):
        logger.error(
            "alembic.ini not found at %s — skipping auto-migration. "
            "Make sure alembic.ini is committed to the repo.",
            alembic_ini,
        )
        return

    logger.info("Running Alembic migrations from: %s", alembic_ini)
    try:
        alembic_cfg = Config(alembic_ini)
        # Ensure the script location is absolute so it works from any cwd
        alembic_cfg.set_main_option(
            "script_location",
            os.path.join(cloud_server_root, "migrations"),
        )
        command.upgrade(alembic_cfg, "head")
        logger.info("Alembic migrations complete.")
    except Exception as exc:
        # Log but do NOT crash the server — a broken migration beats a dead server.
        logger.exception("Alembic migration failed: %s", exc)
        raise  # Re-raise so Render marks the deploy as failed (preferred CI behaviour)
