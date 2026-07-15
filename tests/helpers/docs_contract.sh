#!/usr/bin/env bash
# Copyright 2025-2026 Bootstrap Academy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Cursor Edition doc-contract paths for tests.
#
# Landing README is short and points at MkDocs. Upstream-style operator /
# community documentation contracts are asserted against the MkDocs source:
# docs/en/full-reference.md
#
# Usage (from a test under tests/):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   # shellcheck source=helpers/docs_contract.sh
#   source "$SCRIPT_DIR/tests/helpers/docs_contract.sh"

# shellcheck disable=SC2034  # exported for sourcing tests
LANDING_README="${SCRIPT_DIR}/README.md"
# shellcheck disable=SC2034
OPERATOR_DOC="${SCRIPT_DIR}/docs/en/full-reference.md"
# Back-compat: most upstream tests call this variable README
# shellcheck disable=SC2034
README="${OPERATOR_DOC}"
