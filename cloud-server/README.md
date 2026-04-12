# Cloud Server — LettuVault

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

## Features
- **Offline Batch Syncing:** Exposes endpoints for the hardware's `sync_engine.py` to push cached sensor/AI data using a shared `CLOUD_SYNC_API_KEY`.
- **JWT Authentication:** Manages user Accounts and ties synced records seamlessly to specific users.
- **REST API:** Provides endpoints for the Mobile App to fetch historical data.
