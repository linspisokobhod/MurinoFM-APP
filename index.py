import sys
import os
from PyQt5.QtCore import QUrl
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
from PyQt5.QtWebEngineWidgets import QWebEngineView
from PyQt5.QtGui import QIcon


class RadioApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Мурино FM APP")
        self.setGeometry(100, 100, 420, 780)

        icon_path = os.path.join(os.path.dirname(__file__), 'assets', 'favicon.png')
        if os.path.exists(icon_path):
            self.setWindowIcon(QIcon(icon_path))

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(0, 0, 0, 0)

        self.browser = QWebEngineView()

        html_path = os.path.join(os.path.dirname(__file__), 'assets', 'index.html')
        if os.path.exists(html_path):
            self.browser.setUrl(QUrl.fromLocalFile(html_path))
        else:
            self.browser.setHtml(
                "<h1 style='color:white;background:#0b0e1a;text-align:center;padding-top:50%;'>Файл не найден</h1>"
            )

        layout.addWidget(self.browser)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = RadioApp()
    window.show()
    sys.exit(app.exec())
