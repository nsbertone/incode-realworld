"""
Django settings for config project.

- https://docs.djangoproject.com/en/5.0/topics/settings/ : For more information on this file
- https://docs.djangoproject.com/en/5.0/ref/settings/ : For the full list of settings and their values
- https://docs.djangoproject.com/en/5.0/howto/deployment/checklist/ : Important deployment checklist
"""

import sys
from datetime import timedelta
from os import getenv
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR / "apps"))  # Also allow direct loading of the content in apps


# Security settings
# SECURITY WARNING: Unsuitable for production
# See https://docs.djangoproject.com/en/5.0/howto/deployment/checklist/
# SECURITY WARNING: keep the secret key used in production secret!
# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = str(getenv("DEBUG", False)).lower() == "true"
# Deployment: injected from AWS Secrets Manager (External Secrets). The insecure
# fallback is only allowed for local DEBUG runs and tests.
SECRET_KEY = getenv("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if not DEBUG:
        raise SystemExit("DJANGO_SECRET_KEY must be set when DEBUG is off")
    SECRET_KEY = "django-insecure-local-only"
ALLOWED_HOSTS = ["*"] if DEBUG else (lambda s: s.split(";") if s else [])(getenv("ALLOWED_HOSTS", ""))
CORS_ORIGIN_ALLOW_ALL = True


# Application definition
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Needed for auto-host of Swagger files
    "ninja",
    # 3rd Party Packages
    "corsheaders",
    "django_extensions",
    "jwt_ninja",
    # Local Apps
    "apps.accounts",
    "apps.articles",
    "apps.comments",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"


# Database
# https://docs.djangoproject.com/en/5.0/ref/settings/#databases
# The parsed format follows postgresql://[user[:password]@][netloc][:port][/dbname][?param1=value1&...]
DATABASE_URL = getenv("DATABASE_URL")
if DATABASE_URL and DATABASE_URL.startswith((":memory:", "file:")):
    if not DEBUG:
        raise RuntimeError("In-memory SQLite should only be used with DEBUG=True")
    DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": DATABASE_URL}}
elif DATABASE_URL:
    PARSED_DATABASE_URL = urlparse(DATABASE_URL)
    # Query string options (e.g. ?sslmode=require) are passed to psycopg.
    DATABASE_OPTIONS = {k: v[-1] for k, v in parse_qs(PARSED_DATABASE_URL.query).items()}
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": PARSED_DATABASE_URL.path[1:],
            # Credentials in a URL are percent-encoded (generated RDS passwords
            # contain characters like / : @ that must be escaped): decode them.
            "USER": unquote(PARSED_DATABASE_URL.username or ""),
            "PASSWORD": unquote(PARSED_DATABASE_URL.password or ""),
            "HOST": PARSED_DATABASE_URL.hostname,
            "PORT": PARSED_DATABASE_URL.port,
            "OPTIONS": DATABASE_OPTIONS,
            # Reuse connections across requests, verify them before reuse.
            "CONN_MAX_AGE": int(getenv("DB_CONN_MAX_AGE", "60")),
            "CONN_HEALTH_CHECKS": True,
        }
    }
elif DEBUG:
    DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": BASE_DIR / "db.sqlite3"}}
else:
    raise SystemExit(
        "You should set-up at least one of:\n"
        "- DATABASE_URL to use PostgreSQL - postgresql://[user[:password]@][netloc][:port][/dbname]\n"
        "- DATABASE_URL=':memory:' for in-memory SQLite (DEBUG only)\n"
        "- DEBUG to use file-based SQLite"
    )


# Password validation
# https://docs.djangoproject.com/en/5.0/ref/settings/#auth-password-validators
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

USE_FAST_HASHER = str(getenv("USE_FAST_HASHER", False)).lower() == "true"
if USE_FAST_HASHER and not DEBUG:
    raise RuntimeError("USE_FAST_HASHER should only be used with DEBUG=True")
if USE_FAST_HASHER:
    PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]


# Internationalization
# https://docs.djangoproject.com/en/5.0/topics/i18n/
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.0/howto/static-files/
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"


# Default primary key field type
# https://docs.djangoproject.com/en/5.0/ref/settings/#default-auto-field
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "accounts.User"


# JWT token settings using jwt-ninja
JWT_NINJA = {
    "ACCESS_TOKEN_LIFETIME": timedelta(days=7),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
}


# Logging: everything to stdout (collected by Alloy into Loki). One JSON object
# per line when DJANGO_LOG_FORMAT=json, so Loki can filter on level/logger.
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {"()": "config.logging.JsonFormatter"},
        "plain": {"format": "%(asctime)s %(levelname)s %(name)s %(message)s"},
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "json" if getenv("DJANGO_LOG_FORMAT") == "json" else "plain",
        },
    },
    "root": {"handlers": ["console"], "level": getenv("LOG_LEVEL", "INFO")},
}
