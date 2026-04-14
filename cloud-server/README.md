# Cloud Server — LettuVault
> [!IMPORTANT]
> **Python Version Requirement**: This component requires **Python 3.10.11**.

This is the remote component of the LettuVault system, designed to be deployed on Render or another cloud provider. It serves as the bridge between multiple offline LettuVault hardware instances (Raspberry Pis) and the user's mobile app when they are away from home.

---

## Environment Configuration

When moving from development to production, you will need to manage the configuration in `.env`.

### Testing / Local Development
If you are developing locally on your laptop:
- Ensure `CLOUD_SERVER_LOCAL=true` is set in the **Root Project `.env` file**.
- When you run `lettu_vault_start` at the root, the cloud server will automatically spin up on port `8001`.
- The Mobile App should have `kCloudBaseUrl` pointing to your laptop's local IP address (e.g. `http://192.168.100.20:8001`) inside `lib/src/core/constants.dart`.

### Production Deployment
When deploying to a public host (like Render):
- Use the `cloud-server` directory as your deployment root.
- Set up a real remote PostgreSQL database (like Supabase) and configure the `DATABASE_URL` in the server's environment keys.
- On the Mobile App, change `kCloudBaseUrl` back to your production domain (e.g. `https://lettuvault.onrender.com`).

---

## Database Migrations (Alembic)

This project uses Alembic to manage schema changes on the cloud database.

### 🔁 Workflow for Schema Changes

If you need to add a new table or column to `src/cloud_backend/models/database.py`, follow these steps:

1.  **Modify the Code:** Update the SQLAlchemy models in `src/cloud_backend/models/database.py`.
2.  **Generate Migration File:** Run this command in the `cloud-server` directory:
    ```powershell
    python -m alembic revision --autogenerate -m "describe_your_change"
    ```
3.  **Review:** Open the new file in `migrations/versions/` and verify the `upgrade()` and `downgrade()` functions look correct.
4.  **Commit and Push:** Add the new migration file to Git along with your model changes.

### 🚀 Auto-Migration on Deploy
When you push to Render, the server's startup routine automatically runs:
```python
alembic upgrade head
```
This ensures the production database is always in sync with your latest code without manual intervention.

---

## Features
- **Auto-Migrating Schema:** Uses Alembic to bridge the gap between Python models and the live PostgreSQL DB on deploy.
- **Offline Batch Syncing:** Exposes endpoints for the hardware's `sync_engine.py` to push cached sensor/AI data using a shared `CLOUD_SYNC_API_KEY`.
- **JWT Authentication:** Manages user Accounts and ties synced records seamlessly to specific users.
- **REST API:** Provides endpoints for the Mobile App to fetch historical data.

