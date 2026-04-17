#!/bin/sh
set -e
node_modules/.bin/prisma migrate deploy --schema=packages/prisma/schema.prisma
exec node apps/next/server.js
