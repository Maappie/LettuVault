# 🛠️ LettuVault Script Toolbox

This document lists the custom command-line "shortcuts" created to make development easier for you and your team. These commands are shortcuts to complex `alembic` and `python` tasks.

---

## 🚦 Prerequisites

To use these commands, you MUST have your virtual environment active:

```powershell
.\.venv\Scripts\Activate.ps1
```

---

## 💾 Database Commands (Alembic)

Use these when you want to change your database structure (schema).

| Command                    | Action                | When to use?                               |
| :------------------------- | :-------------------- | :----------------------------------------- |
| **`db-migrate "message"`** | Records a change      | After you edit `database.py`.              |
| **`db-upgrade`**           | Pushes the change     | To apply the changes to your `.db` file.   |
| **`db-history`**           | Shows your timeline   | To see all past changes (like `git log`).  |
| **`db-status`**            | Shows current version | To check if you are on the latest version. |

---

## 🚀 System Bootstrapping

| Command               | Action            | Description                                |
| :-------------------- | :---------------- | :----------------------------------------- |
| **`python start.py`** | Starts everything | Boots up the FastAPI backend and AI paths. |

---

## 📖 Where are these defined?

- **Mapping**: The command names are mapped in the root **`pyproject.toml`** under `[project.scripts]`.
- **Logic**: The actual Python code that runs these commands is located at the bottom of **`backend/src/lettu_backend/main.py`**.

---

## 💡 Troubleshooting

- **"Command not found"**: If your terminal doesn't recognize `db-upgrade`, run `pip install -e .` once more while your `.venv` is active. This "refreshes" the shortcut links.
- **Database Errors**: Make sure you are in the root folder when running these scripts so they can find the `backend/` directory correctly.
