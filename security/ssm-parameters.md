# SSM Parameter Store: Conventions and Examples

This document describes recommended patterns for storing application configuration and secrets using **AWS Systems Manager (SSM) Parameter Store** (SecureString) for the NPS Reporting application.

> Prefer Secrets Manager for credentials that require automatic rotation. SSM Parameter Store is lightweight and fine for many secrets if you manage rotation externally.

---

## 1. Naming conventions

Use hierarchical, environment-aware paths to make parameters discoverable and concise:

