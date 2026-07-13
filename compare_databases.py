import pandas as pd
from sqlalchemy import create_engine, inspect
import sys

# ==========================================
# CONFIGURATION
# ==========================================
DB_CONN_A = {
    "server": "localhost",
    "database": "EMATradeData_SnapshotTests"
}

DB_CONN_B = {
    "server": "localhost",
    "database": "EMATradeData_SnapshotTests_alt"
}

# Set to True to ignore IDENTITY / Auto-increment columns during comparison
IGNORE_IDENTITY = True 

# ==========================================
# HELPER FUNCTIONS
# ==========================================
def get_engine(config):
    """Creates a SQLAlchemy engine for SQL Server using Windows Authentication."""
    conn_str = f"mssql+pyodbc://@{config['server']}/{config['database']}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
    return create_engine(conn_str)

def get_dbo_tables_and_metadata(engine):
    """Fetches all tables in the dbo schema, their columns, and identity status."""
    inspector = inspect(engine)
    tables_meta = {}
    
    for table_name in inspector.get_table_names(schema="dbo"):
        columns = inspector.get_columns(table_name, schema="dbo")
        pk_columns = inspector.get_pk_constraint(table_name, schema="dbo").get('constrained_columns', [])
        
        identity_cols = []
        all_cols = []
        
        for col in columns:
            all_cols.append(col['name'])
            # Check for identity column (dialect specific attribute)
            if col.get('dialect_options', {}).get('mssql_identity', False) or col.get('autoincrement', False):
                identity_cols.append(col['name'])
                
        tables_meta[table_name] = {
            "all_columns": all_cols,
            "pks": pk_columns if pk_columns else [all_cols[0]], # Fallback to first col if no PK
            "identity_cols": identity_cols
        }
    return tables_meta

# ==========================================
# MAIN EXECUTION
# ==========================================
def main():
    print("🔄 Connecting to databases and inspecting schemas...")
    try:
        engine_a = get_engine(DB_CONN_A)
        engine_b = get_engine(DB_CONN_B)
        
        meta_a = get_dbo_tables_and_metadata(engine_a)
        meta_b = get_dbo_tables_and_metadata(engine_b)
    except Exception as e:
        print(f"❌ Connection/Inspection failed: {e}")
        sys.exit(1)

    # Find common tables to compare
    tables_a = set(meta_a.keys())
    tables_b = set(meta_b.keys())
    common_tables = sorted(list(tables_a.intersection(tables_b)))
    
    report = {
        "schema_mismatches": [],
        "passed": [],
        "failed_diffs": {},
        "row_count_mismatches": []
    }
    
    # Track tables missing entirely from one side
    for t in tables_a - tables_b: report["schema_mismatches"].append(f"Table [dbo].[{t}] only exists in DB A.")
    for t in tables_b - tables_a: report["schema_mismatches"].append(f"Table [dbo].[{t}] only exists in DB B.")

    print(f"📋 Found {len(common_tables)} common tables to compare.\n")

    for table in common_tables:
        print(f"Comparing table: [dbo].[{table}]...")
        
        meta = meta_a[table]
        pks = meta["pks"]
        
        # Determine columns to select
        cols_to_select = [c for c in meta["all_columns"]]
        if IGNORE_IDENTITY:
            # Combine identity lists from both DBs to be safe
            id_cols = set(meta_a[table]["identity_cols"] + meta_b[table]["identity_cols"])
            cols_to_select = [c for c in cols_to_select if c not in id_cols]
            # Adjust PK tracking if the original PK was an ignored identity
            pks = [c for c in pks if c not in id_cols]
            if not pks: 
                pks = [cols_to_select[0]] # Fallback to first available column

        # Build SQL query (Ordering by PK is critical for record-by-record comparison)
        cols_str = ", ".join([f"[{c}]" for c in cols_to_select])
        order_str = ", ".join([f"[{c}]" for c in pks])
        query = f"SELECT {cols_str} FROM [dbo].[{table}] ORDER BY {order_str}"
        
        # Load into DataFrames
        df_a = pd.read_sql(query, engine_a)
        df_b = pd.read_sql(query, engine_b)
        
        # Check Row Counts first
        if len(df_a) != len(df_b):
            report["row_count_mismatches"].append(
                f"[dbo].[{table}]: Row count mismatch. DB A has {len(df_a)} rows, DB B has {len(df_b)} rows."
            )
            continue
            
        # If empty and identical
        if df_a.empty and df_b.empty:
            report["passed"].append(table)
            continue

        # Set index to the primary keys/fallback keys for a reliable mapping
        df_a.set_index(pks, inplace=True)
        df_b.set_index(pks, inplace=True)
        
        # Record-by-record comparison
        try:
            # .compare() flags differences. It returns an empty DF if datasets are identical.
            diff = df_a.compare(df_b)
            if diff.empty:
                report["passed"].append(table)
            else:
                report["failed_diffs"][table] = diff
        except Exception as e:
            report["schema_mismatches"].append(f"[dbo].[{table}]: Data alignment failed during comparison. Error: {e}")

    # ==========================================
    # FINAL REPORT GENERATION
    # ==========================================
    print("\n" + "="*50)
    print("📊 FINAL COMPARISON REPORT")
    print("="*50)
    
    print(f"\n✅ SUCCESSFUL MATCHES ({len(report['passed'])} tables):")
    for t in report["passed"]:
        print(f"  - [dbo].[{t}] is identical.")
        
    if report["schema_mismatches"]:
        print(f"\n⚠️ SCHEMA/STRUCTURAL MISMATCHES ({len(report['schema_mismatches'])}):")
        for m in report["schema_mismatches"]:
            print(f"  - {m}")
            
    if report["row_count_mismatches"]:
        print(f"\n🔢 ROW COUNT MISMATCHES ({len(report['row_count_mismatches'])}):")
        for r in report["row_count_mismatches"]:
            print(f"  - {r}")

    if report["failed_diffs"]:
        print(f"\n❌ DATA MISMATCHES ({len(report['failed_diffs'])} tables):")
        for table, diff_df in report["failed_diffs"].items():
            print(f"\n--- Discrepancies in [dbo].[{table}] (Showing first 5 rows) ---")
            # pandas .compare() yields multi-index columns: (column_name, 'self'/'other')
            print(diff_df.head(5))
            print(f"Total mismatched rows in this table: {len(diff_df)}")

if __name__ == "__main__":
    main()