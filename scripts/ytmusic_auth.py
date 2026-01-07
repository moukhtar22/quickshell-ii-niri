#!/usr/bin/env python3
"""
YouTube Music authentication helper
Extracts authentication headers from browser cookies for ytmusicapi/yt-dlp
"""

import sys
import json
import subprocess
import os
import shutil


def get_yt_dlp_path():
    return shutil.which("yt-dlp") or "/usr/bin/yt-dlp"


def get_auth_from_browser(browser="firefox", cookies_file=None):
    """
    Get YouTube Music authentication headers from browser cookies or file
    Uses yt-dlp to extract cookies and creates ytmusicapi auth headers
    """
    yt_dlp = get_yt_dlp_path()

    try:
        # Build yt-dlp command
        cmd = [yt_dlp]

        if cookies_file and os.path.exists(cookies_file):
            # Use custom cookies file
            cmd.extend(["--cookies", cookies_file])
        elif browser:
            # Use browser cookies
            cmd.extend(["--cookies-from-browser", browser])
        else:
            print(
                json.dumps(
                    {
                        "status": "error",
                        "message": "No browser or cookies file specified",
                    }
                )
            )
            return 1

        # We try to fetch a video info to verify cookies work
        # Using a known safe video (YouTube Spotlight)
        cmd.extend(
            [
                "--print",
                "{}",
                "--quiet",
                "--no-warnings",
                "--simulate",
                "https://www.youtube.com/watch?v=jNQXAC9IVRw",
            ]
        )

        # Run with timeout
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)

        if result.returncode == 0:
            # Cookies work! Return success
            source = cookies_file if cookies_file else browser
            print(
                json.dumps(
                    {
                        "status": "success",
                        "source": source,
                        "message": f"Successfully connected using {source}",
                    }
                )
            )
            return 0
        else:
            error_msg = result.stderr.strip() if result.stderr else "Unknown error"
            # Clean up error message to be user friendly
            clean_error = (
                error_msg.split("\n")[0] if error_msg else "Authentication failed"
            )

            if "unsupported" in clean_error.lower():
                clean_error = "Browser not supported or locked"
            elif "cookie" in clean_error.lower():
                clean_error = "Could not read cookies"

            print(
                json.dumps(
                    {
                        "status": "error",
                        "source": cookies_file if cookies_file else browser,
                        "message": clean_error,
                    }
                )
            )
            return 1

    except subprocess.TimeoutExpired:
        print(json.dumps({"status": "error", "message": "Connection timeout"}))
        return 1
    except Exception as e:
        print(json.dumps({"status": "error", "message": f"Error: {str(e)}"}))
        return 1


def main():
    browser = None
    cookies_file = None

    if len(sys.argv) >= 2:
        arg = sys.argv[1].strip()
        if arg and os.path.exists(arg):
            cookies_file = arg
        elif arg:
            browser = arg

    if len(sys.argv) >= 3:
        cookies_file = sys.argv[2].strip() if sys.argv[2].strip() else None

    if not browser and not cookies_file:
        browser = "firefox"  # Default

    # Ensure browser is a string if it was None (though logic above handles it)
    browser_str = browser if browser else ""

    return get_auth_from_browser(browser_str, cookies_file)


if __name__ == "__main__":
    sys.exit(main())
