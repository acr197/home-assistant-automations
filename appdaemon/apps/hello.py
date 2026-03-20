import os
import appdaemon.plugins.hass.hassapi as hass

try:
    import cups
    CUPS_AVAILABLE = True
except ImportError:
    CUPS_AVAILABLE = False

CUPS_HOST = "192.168.0.100"
CUPS_PORT = 631
PDF_PATH = "/config/www/print/testpage.pdf"


class HelloWorld(hass.Hass):

    def initialize(self):
        self.log("=== Printer app initializing ===")
        if not CUPS_AVAILABLE:
            self.log(
                "WARNING: pycups is not installed — print jobs will fail. "
                "Install it in the AppDaemon addon: pip install pycups"
            )
        else:
            self.log("pycups is available")

        pdf_exists = os.path.exists(PDF_PATH)
        self.log(f"PDF path: {PDF_PATH} — {'EXISTS' if pdf_exists else 'MISSING'}")

        # Always register the listener so we can confirm event receipt in logs
        # even if pycups is missing or the PDF is not yet in place.
        self.listen_event(self.on_print_purge, "plz_print_purge")
        self.log("Listening for plz_print_purge event — initialization complete")

    def on_print_purge(self, event_name, data, kwargs):
        self.log(f"=== plz_print_purge received (event_name={event_name}, data={data}) ===")
        self.print_purge()

    def print_purge(self):
        if not CUPS_AVAILABLE:
            self.log(
                "ERROR: pycups not installed — cannot print. "
                "Install pycups in the AppDaemon addon Python environment."
            )
            return

        if not os.path.exists(PDF_PATH):
            self.log(f"ERROR: PDF not found at {PDF_PATH} — cannot print")
            return

        self.log(f"Connecting to CUPS at {CUPS_HOST}:{CUPS_PORT}")
        try:
            conn = cups.Connection(host=CUPS_HOST, port=CUPS_PORT)
        except Exception as e:
            self.log(f"ERROR: Failed to connect to CUPS at {CUPS_HOST}:{CUPS_PORT} — {e}")
            return

        try:
            printers = conn.getPrinters()
        except Exception as e:
            self.log(f"ERROR: Failed to list printers from CUPS — {e}")
            return

        if not printers:
            self.log(f"ERROR: No printers found on CUPS server {CUPS_HOST}:{CUPS_PORT}")
            return

        self.log(f"Available printers: {list(printers.keys())}")

        try:
            printer = conn.getDefault()
        except Exception as e:
            self.log(f"WARNING: Could not get default printer — {e}")
            printer = None

        if not printer:
            printer = list(printers.keys())[0]
            self.log(f"No default printer set — falling back to first available: {printer}")
        else:
            self.log(f"Using default printer: {printer}")

        try:
            job_id = conn.printFile(printer, PDF_PATH, "HA Monthly Test Page", {})
            self.log(f"Print job submitted — printer={printer}, job_id={job_id}, file={PDF_PATH}")
        except Exception as e:
            self.log(f"ERROR: printFile failed — printer={printer}, file={PDF_PATH} — {e}")
