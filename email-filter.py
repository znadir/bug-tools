import os
import argparse


LOGO = """  ______                 _ _  __ _ _ _
 |  ____|               (_) |/ _(_) | |
 | |__   _ __ ___   __ _ _| | |_ _| | |_ ___ _ __
 |  __| | '_ ` _ \\ / _` | | |  _| | | __/ _ \\ '__|
 | |____| | | | | | (_| | | | | | | | ||  __/ |
 |______|_| |_| |_|\\__,_|_|_|_| |_|_|\\__\\___|_|\n"""


def filter_emails(file_path):
    file_path = os.path.join(os.path.dirname(__file__), file_path)

    try:
        with open(file_path) as f:
            lines = f.readlines()

        email_lines = [line.replace("\n", "") for line in lines if "@" in line]
        emails = list(set(email_lines))

        for email in emails:
            print(email)

        print(f"\nTotal emails: {len(emails)}\n")
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    print(LOGO)
    parser = argparse.ArgumentParser(description="Filter emails from a file.")
    parser.add_argument("file_path", help="Path to the file containing emails")

    args = parser.parse_args()

    filter_emails(args.file_path)
