from ingestion_utils import connect_snowflake


def main() -> None:
    connection = connect_snowflake()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                select
                    current_account(),
                    current_region(),
                    current_user(),
                    current_role(),
                    current_warehouse(),
                    current_database(),
                    current_schema()
                """
            )
            row = cursor.fetchone()
    finally:
        connection.close()

    print("Snowflake connection succeeded.")
    print(f"Account: {row[0]}")
    print(f"Region: {row[1]}")
    print(f"User: {row[2]}")
    print(f"Role: {row[3]}")
    print(f"Warehouse: {row[4]}")
    print(f"Database: {row[5]}")
    print(f"Schema: {row[6]}")


if __name__ == "__main__":
    main()
