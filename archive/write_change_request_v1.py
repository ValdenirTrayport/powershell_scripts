import json
import os
import subprocess
import sys

def ensure_az_logged_in():
    """Checks if the user is logged into Azure CLI. If not, triggers interactive login."""
    print("[LOG] Checking Azure CLI authentication status...")
    
    # We use a lightweight command to check if we are authenticated
    check_cmd = "az account show --output json" if os.name == 'nt' else ["az", "account", "show", "--output", "json"]
    
    try:
        subprocess.run(
            check_cmd, 
            capture_output=True, 
            text=True, 
            check=True, 
            shell=(os.name == 'nt'), 
            timeout=10
        )
        print("[LOG] Authentication verified successfully.")
        return True
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        print("\n[LOG] Active login session not found. Launching interactive 'az login'...")
        print("[LOG] Your web browser should open shortly. Please authenticate there.\n")
        
        login_cmd = "az login" if os.name == 'nt' else ["az", "login"]
        try:
            # We do NOT capture output here so the user can see the browser redirect instructions
            subprocess.run(login_cmd, shell=(os.name == 'nt'), check=True)
            print("\n[LOG] Login successful! Proceeding with script...")
            return True
        except subprocess.CalledProcessError:
            print("\n[ERROR] 'az login' failed or was cancelled by the user.", file=sys.stderr)
            return False

def run_az_command(command_list, step_description=""):
    try:
        if os.name == 'nt':
            # Handle Windows shell formatting issues cleanly
            cmd_string = []
            for arg in command_list:
                if any(char in arg for char in (' ', '(', ')', "'", '"')):
                    cmd_string.append(f'"{arg}"')
                else:
                    cmd_string.append(arg)
            final_cmd = " ".join(cmd_string)
        else:
            final_cmd = command_list

        print(f"[LOG] Executing: {final_cmd if isinstance(final_cmd, str) else ' '.join(final_cmd)}")
        
        result = subprocess.run(
            final_cmd, 
            capture_output=True, 
            text=True, 
            check=True, 
            shell=(os.name == 'nt'),
            timeout=30  
        )
        return json.loads(result.stdout)

    except subprocess.TimeoutExpired:
        print(f"\n[TIMEOUT ERROR] Command timed out during: {step_description}", file=sys.stderr)
        return None
    except subprocess.CalledProcessError as e:
        print(f"\n[PROCESS ERROR] Command failed with exit code {e.returncode}", file=sys.stderr)
        print(f"[DEBUG INFO] STDERR:\n{e.stderr}", file=sys.stderr)
        return None
    except json.JSONDecodeError:
        print(f"\n[JSON ERROR] Failed to parse output as JSON.", file=sys.stderr)
        return None

def main():
    # Force Azure CLI to bypass interactive extension prompts
    os.environ["AZURE_EXTENSION_AUTO_INSTALL"] = "yes"

    # Step 0: Ensure the user is authenticated before proceeding
    if not ensure_az_logged_in():
        print("[LOG] Script stopped due to authentication failure.")
        return

    tag_input = input("\nEnter the tag you want to filter by (default: BARRI): ").strip()
    target_tag = tag_input if tag_input else "BARRI"

    org = "https://dev.azure.com/trayport"
    project = "Business"
    target_column = "Awaiting Release"

    print(f"\n[LOG] Querying Azure DevOps for tag '{target_tag}' in column '{target_column}'...")

    # Server-side query 
    wiql = (
        f"SELECT [System.Id] FROM workitems "
        f"WHERE [System.TeamProject] = '{project}' "
        f"AND ([System.WorkItemType] = 'Product Backlog Item' OR [System.WorkItemType] = 'Bug') "
        f"AND [System.Tags] CONTAINS '{target_tag}' "
        f"AND [System.BoardColumn] = '{target_column}'"
    )

    query_cmd = [
        "az", "boards", "query",
        "--wiql", wiql,
        "--org", org,
        "--project", project,
        "--output", "json"
    ]

    results = run_az_command(query_cmd, step_description="Server-side WIQL Filtering Query")
    if not results:
        print("[LOG] Script stopped. Query returned 0 results or failed.")
        return

    print(f"[LOG] Server returned exactly {len(results)} items matching criteria. Fetching specific details...")

    pbis = []
    bugs = []

    for index, item_ref in enumerate(results, start=1):
        work_item_id = item_ref.get("id")
        if not work_item_id:
            continue

        show_cmd = [
            "az", "boards", "work-item", "show",
            "--id", str(work_item_id),
            "--org", org,
            "--output", "json"
        ]
        
        item_data = run_az_command(show_cmd, step_description=f"Fetching details for ID {work_item_id}")
        if not item_data:
            continue

        fields = item_data.get("fields", {})
        wi_type = fields.get("System.WorkItemType")
        title = fields.get("System.Title")
        wi_id = fields.get("System.Id")

        # Format item layout exactly as specified
        formatted_str = (
            f"{wi_type} {wi_id} - {title}\n"
            f"https://dev.azure.com/trayport/Business/_workitems/edit/{wi_id}"
        )

        if wi_type == "Product Backlog Item":
            pbis.append(formatted_str)
        elif wi_type == "Bug":
            bugs.append(formatted_str)

    # Output final results: Product Backlog Items first, then Bugs
    print("\n" + "="*20 + " FINAL GENERATED TEXT " + "="*20 + "\n")
    
    if not pbis and not bugs:
        print(f"No items found in column '{target_column}' matching tag '{target_tag}'.")

    for pbi in pbis:
        print(pbi)
        print()

    for bug in bugs:
        print(bug)
        print()

if __name__ == "__main__":
    main()