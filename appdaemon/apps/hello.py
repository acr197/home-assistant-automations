import appdaemon.plugins.hass.hassapi as hass

try:
    import cups
    CUPS_AVAILABLE = True
except ImportError:
    CUPS_AVAILABLE = False


class HelloWorld(hass.Hass):

  def initialize(self):
    self.log("Printer app initializing")
    if not CUPS_AVAILABLE:
      self.log("ERROR: pycups is not installed — printing will not work")
      return
    self.listen_event(self.mode_event, "plz_print_purge")
    self.log("Printer app ready, listening for plz_print_purge")

  def mode_event(self, event, data, kwargs):
    self.log("plz_print_purge received, starting print")
    self.print_purge()
    self.log("Print job submitted")

  def print_purge(self):
    cups.setServer("192.168.0.100")
    conn = cups.Connection(host="192.168.0.100", port=631)

    printer = conn.getDefault()
    if not printer:
      self.log("ERROR: No default printer found at 192.168.0.100:631")
      return

    self.log(f"Printing on {printer}")
    job_id = conn.printFile(printer, "/config/www/print/testpage.pdf", "Print Job", {})
    self.log(f"Print job submitted with ID: {job_id}")
