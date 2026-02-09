#!/bin/bash
# extract-context-beans.sh — Parse Spring context XML files into structured JSON
# Usage: bash extract-context-beans.sh [project_root] [output_file]
# Output: JSON catalog of all Spring bean definitions

set -euo pipefail

PROJECT_ROOT="${1:-.}"
OUTPUT_FILE="${2:-.migration/context-beans.json}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

WEBAPP_DIR="$PROJECT_ROOT/webapp"

if [ ! -d "$WEBAPP_DIR" ]; then
    echo '{"beans": [], "files": []}' > "$OUTPUT_FILE"
    echo "No webapp directory found" >&2
    exit 0
fi

CTX_FILES=$(find "$WEBAPP_DIR" -name "*_context.xml" 2>/dev/null | sort)

if [ -z "$CTX_FILES" ]; then
    echo '{"beans": [], "files": []}' > "$OUTPUT_FILE"
    echo "No context XML files found" >&2
    exit 0
fi

echo "=== Extracting Spring Context Beans ===" >&2

# Build JSON manually (awk-based XML parsing)
BEANS_JSON="["
FILES_JSON="["
FIRST_BEAN=true
FIRST_FILE=true

while IFS= read -r ctx_file; do
    [ -z "$ctx_file" ] && continue

    $FIRST_FILE || FILES_JSON="$FILES_JSON,"
    FIRST_FILE=false
    FILES_JSON="$FILES_JSON\"$ctx_file\""

    echo "  Processing: $ctx_file" >&2

    # Extract bean definitions using awk
    # We parse: <bean id="..." class="..." scope="...">
    #   <constructor-arg ref="..." />
    #   <constructor-arg value="..." />
    #   <property name="..." value="..." />
    #   <property name="..." ref="..." />
    # </bean>
    while IFS= read -r bean_line; do
        [ -z "$bean_line" ] && continue

        BEAN_ID=$(echo "$bean_line" | grep -oP 'id="\K[^"]+' | tr -d '\r' || echo "")
        BEAN_CLASS=$(echo "$bean_line" | grep -oP 'class="\K[^"]+' | tr -d '\r' || echo "")
        BEAN_SCOPE=$(echo "$bean_line" | grep -oP 'scope="\K[^"]+' | tr -d '\r' || echo "singleton")
        BEAN_NAME=$(echo "$bean_line" | grep -oP 'name="\K[^"]+' | tr -d '\r' || echo "")

        [ -z "$BEAN_CLASS" ] && [ -z "$BEAN_ID" ] && continue

        # Extract constructor args and properties from the bean block
        CONSTRUCTOR_ARGS="[]"
        PROPERTIES="[]"
        REFS="[]"

        # Get the full bean block (from <bean to </bean>)
        BLOCK=$(awk -v id="$BEAN_ID" '
            $0 ~ "id=\"" id "\"" { found=1 }
            found { block = block $0 "\n" }
            found && /<\/bean>/ { print block; found=0 }
        ' "$ctx_file" 2>/dev/null || true)

        if [ -n "$BLOCK" ]; then
            # Constructor args
            CA_JSON="["
            FIRST_CA=true
            while IFS= read -r ca_line; do
                [ -z "$ca_line" ] && continue
                CA_REF=$(echo "$ca_line" | grep -oP 'ref="\K[^"]+' | tr -d '\r' || echo "")
                CA_VAL=$(echo "$ca_line" | grep -oP 'value="\K[^"]+' | tr -d '\r' || echo "")
                $FIRST_CA || CA_JSON="$CA_JSON,"
                FIRST_CA=false
                if [ -n "$CA_REF" ]; then
                    CA_JSON="$CA_JSON{\"ref\":\"$CA_REF\"}"
                elif [ -n "$CA_VAL" ]; then
                    CA_JSON="$CA_JSON{\"value\":\"$CA_VAL\"}"
                fi
            done < <(echo "$BLOCK" | grep 'constructor-arg')
            CA_JSON="$CA_JSON]"
            CONSTRUCTOR_ARGS="$CA_JSON"

            # Properties
            PR_JSON="["
            FIRST_PR=true
            while IFS= read -r pr_line; do
                [ -z "$pr_line" ] && continue
                PR_NAME=$(echo "$pr_line" | grep -oP 'name="\K[^"]+' | tr -d '\r' || echo "")
                PR_REF=$(echo "$pr_line" | grep -oP 'ref="\K[^"]+' | tr -d '\r' || echo "")
                PR_VAL=$(echo "$pr_line" | grep -oP 'value="\K[^"]+' | tr -d '\r' || echo "")
                [ -z "$PR_NAME" ] && continue
                $FIRST_PR || PR_JSON="$PR_JSON,"
                FIRST_PR=false
                if [ -n "$PR_REF" ]; then
                    PR_JSON="$PR_JSON{\"name\":\"$PR_NAME\",\"ref\":\"$PR_REF\"}"
                elif [ -n "$PR_VAL" ]; then
                    PR_JSON="$PR_JSON{\"name\":\"$PR_NAME\",\"value\":\"$PR_VAL\"}"
                else
                    PR_JSON="$PR_JSON{\"name\":\"$PR_NAME\"}"
                fi
            done < <(echo "$BLOCK" | grep '<property ')
            PR_JSON="$PR_JSON]"
            PROPERTIES="$PR_JSON"

            # All refs (both constructor-arg and property)
            REF_JSON="["
            FIRST_REF=true
            while IFS= read -r ref_val; do
                [ -z "$ref_val" ] && continue
                $FIRST_REF || REF_JSON="$REF_JSON,"
                FIRST_REF=false
                REF_JSON="$REF_JSON\"$ref_val\""
            done < <(echo "$BLOCK" | grep -oP 'ref="\K[^"]+' | tr -d '\r' | sort -u)
            REF_JSON="$REF_JSON]"
            REFS="$REF_JSON"
        fi

        # Determine if this bean needs a CDI producer
        NEEDS_PRODUCER=false
        [ "$CONSTRUCTOR_ARGS" != "[]" ] && NEEDS_PRODUCER=true
        [ "$PROPERTIES" != "[]" ] && NEEDS_PRODUCER=true

        $FIRST_BEAN || BEANS_JSON="$BEANS_JSON,"
        FIRST_BEAN=false
        BEANS_JSON="$BEANS_JSON{\"id\":\"${BEAN_ID:-$BEAN_NAME}\",\"class\":\"$BEAN_CLASS\",\"scope\":\"$BEAN_SCOPE\",\"constructorArgs\":$CONSTRUCTOR_ARGS,\"properties\":$PROPERTIES,\"refs\":$REFS,\"needsProducer\":$NEEDS_PRODUCER,\"sourceFile\":\"$ctx_file\"}"

    done < <(grep '<bean ' "$ctx_file" 2>/dev/null)

done <<< "$CTX_FILES"

BEANS_JSON="$BEANS_JSON]"
FILES_JSON="$FILES_JSON]"

# Write output
cat << ENDJSON > "$OUTPUT_FILE"
{
  "beans": $BEANS_JSON,
  "files": $FILES_JSON
}
ENDJSON

BEAN_COUNT=$(echo "$BEANS_JSON" | { grep -o '"id"' || true; } | wc -l)
echo "" >&2
echo "=== Extracted $BEAN_COUNT beans from $(echo "$FILES_JSON" | grep -o '"' | wc -l | awk '{print $1/2}') context files ===" >&2
echo "Output: $OUTPUT_FILE" >&2
