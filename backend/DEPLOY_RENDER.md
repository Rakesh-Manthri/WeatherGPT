# 🚀 Production Deployment Guide for Render

This document provides a step-by-step walkthrough to deploy the **WeatherGPT FastAPI Backend** to [Render](https://render.com) for production.

---

## 📋 Prerequisites

Before deploying, ensure you have:
1. A **GitHub** or **GitLab** account with this repository pushed.
2. A free account on [Render.com](https://dashboard.render.com).
3. Your **Google Gemini API Key** (`GEMINI_API_KEY`).
4. Your **Supabase Project URL and Keys** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`).

---

## 🌟 Method 1: Automatic Blueprint Deploy (Recommended)

Render provides native **Infrastructure-as-Code** support via the [`render.yaml`](../render.yaml) file included in the root of this repository.

### Steps:
1. Log into [Render Dashboard](https://dashboard.render.com).
2. Click **New +** in the top right and select **Blueprint**.
3. Connect your GitHub repository containing **WeatherGPT**.
4. Render will automatically detect `render.yaml` and configure:
   - **Service Name**: `weathergpt-backend`
   - **Environment**: Python 3.11.9
   - **Root Directory**: `backend`
   - **Build Command**: `pip install --upgrade pip && pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2`
   - **Health Check**: `/health`
5. Fill in the prompted secret environment variables:
   - `GEMINI_API_KEY`: *(Your Gemini API Key)*
   - `SUPABASE_URL`: *(Your Supabase project URL)*
   - `SUPABASE_ANON_KEY`: *(Your Supabase anon key)*
   - `SUPABASE_SERVICE_KEY`: *(Your Supabase service role key)*
6. Click **Apply**. Render will build and deploy your backend!

---

## 🛠️ Method 2: Manual Web Service Setup

If you prefer to configure the service manually on Render:

1. Go to [Render Dashboard](https://dashboard.render.com) ➔ **New +** ➔ **Web Service**.
2. Select your repository.
3. Configure the settings:
   | Field | Value |
   |---|---|
   | **Name** | `weathergpt-backend` |
   | **Region** | Choose the region closest to your users (e.g. *Singapore*, *Oregon*, *Frankfurt*) |
   | **Branch** | `main` |
   | **Root Directory** | `backend` |
   | **Runtime** | `Python 3` |
   | **Build Command** | `pip install --upgrade pip && pip install -r requirements.txt` |
   | **Start Command** | `uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2` |
   | **Instance Type** | `Free` (or `Starter`) |

4. Scroll down to **Advanced** ➔ **Health Check Path** and enter:
   ```
   /health
   ```

5. Under **Environment Variables**, add the following keys:
   | Key | Value | Notes |
   |---|---|---|
   | `PYTHON_VERSION` | `3.11.9` | Ensures exact Python runtime |
   | `ENVIRONMENT` | `production` | Production mode |
   | `CORS_ORIGINS` | `*` | Or specify allowed domains |
   | `GEMINI_API_KEY` | `AIzaSy...` | Your Google GenAI key |
   | `SUPABASE_URL` | `https://xxxx.supabase.co` | Supabase endpoint |
   | `SUPABASE_ANON_KEY` | `eyJ...` | Supabase Anon Key |
   | `SUPABASE_SERVICE_KEY`| `eyJ...` | Supabase Service Role Key |

6. Click **Create Web Service**.

---

## 🔍 Verifying the Deployment

Once Render finishes deploying:
1. Copy your live Render URL (e.g., `https://weathergpt-backend.onrender.com`).
2. Test the **Health Check**:
   ```bash
   curl https://weathergpt-backend.onrender.com/health
   ```
   **Expected Response:**
   ```json
   {"status":"healthy","version":"1.0.0","environment":"production","ai_ready":true}
   ```
3. Test the **Interactive Swagger Docs**:
   Open in browser:
   ```
   https://weathergpt-backend.onrender.com/docs
   ```
4. Test the **Chat Completion Endpoint**:
   ```bash
   curl -X POST https://weathergpt-backend.onrender.com/api/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"message": "What is the weather like in Tokyo?", "session_id": "test_1"}'
   ```

---

## 📱 Connecting the Flutter App to Production

1. Open `.env` at the root of the Flutter project.
2. Add or update the `BACKEND_URL` variable with your deployed Render URL:
   ```env
   BACKEND_URL=https://weathergpt-backend.onrender.com
   ```
3. The Flutter `WeatherApiClient` will automatically prioritize your live Render production server with automatic fallback to local devices if offline.
