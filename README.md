# GeoTrainer
**A training module for Geoguessr, designed to help players improve in a structured and collaborative way.**

---

## 📌 Introduction
GeoTrainer is an open-source tool built with the **Godot 4** engine, aiming to provide a simple and accessible interface for:
- Tracking progress.
- Accessing training resources.
- Participating in personalized training programs.
- Retrieving player statistics via an API.

This project is **collaborative**: contributions are welcome, provided they follow the development and version control best practices.

---

## 📖 Project Description
### Key Features
- **Dashboard**: Personalized dashboard to track progress.
- **Training**: Access to training maps and automated programs.
- **Resources**: Guides, tips, and useful links to improve.
- **API**: Retrieve player statistics (future integration).

### Technologies Used
- **Engine**: [Godot 4](https://godotengine.org/) (GDScript).
- **Version Control**: Git (workflow based on `main` and `dev` branches).
- **Collaboration**: GitHub/GitLab (Pull Requests, Issues, Projects).

---

## 🔄 Version Control Best Practices
### 📂 Branch Structure
| Branch          | Role                                                                 |
|-----------------|----------------------------------------------------------------------|
| `main`          | Stable branch. **Only the project maintainer can merge into it.**   |
| `dev`           | Development branch. Integrates validated features.                  |
| `feature/*`     | Development of new features (e.g., `feature/dashboard`).           |
| `fix/*`         | Bug fixes (e.g., `fix/api-error`).                                   |

### 🔄 Collaborative Workflow
1. **Create a branch** from `dev`:
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feature/my-feature
