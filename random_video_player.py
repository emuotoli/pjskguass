import json
import random
import os
import sys
import webbrowser
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QListWidget, QListWidgetItem,
    QFrame, QSplitter, QProgressBar, QStatusBar, QMessageBox,
    QSlider, QSizePolicy, QStyle
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QTimer, QUrl
from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
from PyQt5.QtMultimediaWidgets import QVideoWidget

from bili_config import get_cookies_dict


# 凭证从环境变量或本地 cookies.local.json 读取，未配置时为空
COOKIES = get_cookies_dict()


def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(__file__)
    return os.path.join(base_path, relative_path)


class DownloadThread(QThread):
    progress = pyqtSignal(int)
    finished = pyqtSignal(str)
    error = pyqtSignal(str)

    def __init__(self, bvid, save_dir):
        super().__init__()
        self.bvid = bvid
        self.save_dir = save_dir
        self.is_running = True
        self.downloaded_file = None

    def run(self):
        try:
            import time
            self.start_time = time.time()
            import yt_dlp
            
            url = f"https://www.bilibili.com/video/{self.bvid}"
            
            ydl_opts = {
                'outtmpl': os.path.join(self.save_dir, '%(title)s.%(ext)s'),
                'format': 'bv*+ba/b',
                'noplaylist': True,
                'quiet': True,
                'no_warnings': True,
                'merge_output_format': 'mp4',
                'http_headers': {
                    'Cookie': '; '.join([f'{k}={v}' for k, v in COOKIES.items()]),
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Referer': 'https://www.bilibili.com/'
                },
                'progress_hooks': [self.progress_hook],
                'postprocessor_hooks': [self.postprocessor_hook],
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            
            if self.downloaded_file and os.path.exists(self.downloaded_file):
                self.finished.emit(self.downloaded_file)
            else:
                for filename in os.listdir(self.save_dir):
                    if filename.endswith('.mp4'):
                        filepath = os.path.join(self.save_dir, filename)
                        if os.path.getmtime(filepath) > (self.start_time - 60):
                            self.downloaded_file = filepath
                            self.finished.emit(filepath)
                            return
                self.finished.emit("")
                
        except Exception as e:
            self.error.emit(str(e))

    def progress_hook(self, d):
        if d['status'] == 'downloading':
            try:
                downloaded = d.get('downloaded_bytes') or 0
                total = d.get('total_bytes') or 1
                percent = int(downloaded / total * 100)
                self.progress.emit(percent)
            except:
                pass

    def postprocessor_hook(self, d):
        if d['status'] == 'finished':
            self.downloaded_file = d.get('filename', '')

    def stop(self):
        self.is_running = False


class RandomVideoPlayer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("🎵 官方MV合集 - 随机抽选播放器")
        self.setGeometry(100, 100, 1100, 700)
        
        self.videos = self.load_videos()
        self.current_video = None
        self.picked_history = []
        self.download_dir = os.path.join(os.path.dirname(__file__), 'downloaded_videos')
        self.index_file = os.path.join(self.download_dir, 'index.json')
        os.makedirs(self.download_dir, exist_ok=True)
        
        self.download_thread = None
        self.is_downloading = False
        
        self.setup_player()
        self.setup_ui()
        self.load_download_index()
    
    def setup_player(self):
        self.media_player = QMediaPlayer(None, QMediaPlayer.VideoSurface)
        self.video_widget = QVideoWidget()
        self.video_widget.setStyleSheet("background-color: #000;")
        
        self.media_player.setVideoOutput(self.video_widget)
        
        self.media_player.stateChanged.connect(self.on_player_state_changed)
        self.media_player.positionChanged.connect(self.on_position_changed)
        self.media_player.durationChanged.connect(self.on_duration_changed)
        self.media_player.error.connect(self.on_player_error)
    
    def load_videos(self):
        try:
            json_path = resource_path('bilibili_mv_videos.json')
            with open(json_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"加载视频数据失败: {e}")
            return []
    
    def load_download_index(self):
        if os.path.exists(self.index_file):
            try:
                with open(self.index_file, 'r', encoding='utf-8') as f:
                    self.download_index = json.load(f)
            except:
                self.download_index = {}
        else:
            self.download_index = {}
    
    def save_download_index(self):
        with open(self.index_file, 'w', encoding='utf-8') as f:
            json.dump(self.download_index, f)
    
    def format_duration(self, seconds):
        if not seconds:
            return "未知"
        mins = seconds // 60
        secs = seconds % 60
        return f"{mins:02d}:{secs:02d}"
    
    def format_time(self, seconds):
        mins = seconds // 60
        secs = seconds % 60
        return f"{mins:02d}:{secs:02d}"
    
    def check_video_downloaded(self, bvid):
        if bvid in self.download_index:
            filepath = self.download_index[bvid]
            if os.path.exists(filepath):
                return filepath
        
        for filename in os.listdir(self.download_dir):
            if filename.endswith('.mp4'):
                filepath = os.path.join(self.download_dir, filename)
                if os.path.exists(filepath):
                    if bvid in filename:
                        self.download_index[bvid] = filepath
                        self.save_download_index()
                        return filepath
        
        return None
    
    def pick_random(self):
        if self.is_downloading:
            QMessageBox.warning(self, "提示", "正在下载中，请等待完成")
            return
        
        if not self.videos:
            QMessageBox.warning(self, "提示", "没有视频数据")
            return
        
        try:
            self.current_video = random.choice(self.videos)
            self.picked_history.append(self.current_video)
            
            self.title_label.setText(self.current_video['title'])
            self.bvid_label.setText(f"BVID: {self.current_video['bvid']}")
            self.duration_label.setText(f"时长: {self.format_duration(self.current_video.get('duration'))}")
            self.count_label.setText(f"已抽选: {len(self.picked_history)} / {len(self.videos)}")
            
            self.update_history()
            
            local_path = self.check_video_downloaded(self.current_video['bvid'])
            if local_path:
                self.play_local_video(local_path)
            else:
                self.start_download(self.current_video['bvid'])
        except Exception as e:
            QMessageBox.critical(self, "错误", f"抽选失败: {str(e)}")
            print(f"抽选失败: {str(e)}")
    
    def start_download(self, bvid):
        self.is_downloading = True
        self.statusBar().showMessage(f"正在下载: {bvid}...")
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        self.btn_pick.setEnabled(False)
        
        self.download_thread = DownloadThread(bvid, self.download_dir)
        self.download_thread.progress.connect(self.update_progress)
        self.download_thread.finished.connect(self.on_download_finished)
        self.download_thread.error.connect(self.on_download_error)
        self.download_thread.start()
    
    def update_progress(self, percent):
        self.progress_bar.setValue(percent)
        self.statusBar().showMessage(f"下载中: {percent}%")
    
    def on_download_finished(self, filepath):
        self.is_downloading = False
        self.progress_bar.setVisible(False)
        self.btn_pick.setEnabled(True)
        
        if filepath and os.path.exists(filepath):
            self.statusBar().showMessage(f"下载完成: {os.path.basename(filepath)}")
            
            if self.current_video:
                self.download_index[self.current_video['bvid']] = filepath
                self.save_download_index()
            
            self.update_downloaded_list()
            self.update_history()
            self.play_local_video(filepath)
        else:
            self.statusBar().showMessage("下载完成，正在查找文件...")
            QTimer.singleShot(1000, self.find_and_play_downloaded)
    
    def find_and_play_downloaded(self):
        if self.current_video:
            local_path = self.check_video_downloaded(self.current_video['bvid'])
            if local_path:
                self.play_local_video(local_path)
            else:
                self.statusBar().showMessage("未找到下载的文件")
    
    def on_download_error(self, error_msg):
        self.is_downloading = False
        self.progress_bar.setVisible(False)
        self.btn_pick.setEnabled(True)
        self.statusBar().showMessage(f"下载失败: {error_msg}")
        QMessageBox.critical(self, "下载失败", error_msg)
    
    def play_local_video(self, filepath):
        try:
            if os.path.exists(filepath):
                self.media_player.stop()
                media_content = QMediaContent(QUrl.fromLocalFile(filepath))
                self.media_player.setMedia(media_content)
                self.media_player.play()
                self.statusBar().showMessage(f"播放中: {os.path.basename(filepath)}")
                self.btn_play.setText('⏸')
            else:
                self.statusBar().showMessage("文件不存在")
                QMessageBox.warning(self, "文件不存在", f"无法找到文件: {filepath}")
        except Exception as e:
            QMessageBox.critical(self, "播放失败", str(e))
            print(f"播放失败: {str(e)}")
    
    def on_player_state_changed(self, state):
        if state == QMediaPlayer.PlayingState:
            self.btn_play.setText('⏸')
            self.statusBar().showMessage("播放中")
        elif state == QMediaPlayer.PausedState:
            self.btn_play.setText('▶')
            self.statusBar().showMessage("已暂停")
        elif state == QMediaPlayer.StoppedState:
            self.btn_play.setText('▶')
            self.statusBar().showMessage("已停止")
    
    def on_position_changed(self, position):
        self.slider_progress.setValue(position)
        duration = self.media_player.duration()
        if duration > 0:
            self.label_time.setText(f"{self.format_time(position // 1000)} / {self.format_time(duration // 1000)}")
    
    def on_duration_changed(self, duration):
        self.slider_progress.setRange(0, duration)
    
    def on_player_error(self, error):
        error_str = ""
        if error == QMediaPlayer.NoError:
            return
        elif error == QMediaPlayer.ResourceError:
            error_str = "资源错误：无法读取视频文件"
        elif error == QMediaPlayer.FormatError:
            error_str = "格式错误：视频格式不支持"
        elif error == QMediaPlayer.NetworkError:
            error_str = "网络错误：无法连接到网络"
        elif error == QMediaPlayer.AccessDeniedError:
            error_str = "访问被拒绝：没有权限播放此视频"
        elif error == QMediaPlayer.ServiceMissingError:
            error_str = "服务缺失：缺少必要的媒体服务"
        else:
            error_str = f"未知错误 (代码: {error})"
        
        self.statusBar().showMessage(f"播放错误: {error_str}")
        QMessageBox.critical(self, "播放错误", f"{error_str}\n\n请确保已安装视频解码器（如LAV Filters）")
        print(f"播放错误: {error_str}")
    
    def play_pause(self):
        try:
            if self.media_player.state() == QMediaPlayer.PlayingState:
                self.media_player.pause()
            else:
                self.media_player.play()
        except Exception as e:
            QMessageBox.warning(self, "操作失败", str(e))
            print(f"播放/暂停操作失败: {str(e)}")
    
    def set_position(self, position):
        try:
            self.media_player.setPosition(position)
        except Exception as e:
            pass
    
    def update_history(self):
        self.history_list.clear()
        
        if len(self.picked_history) == 0:
            self.history_list.addItem("暂无抽选记录")
            return
        
        for i, video in enumerate(reversed(self.picked_history), 1):
            title = video['title'][:35] + "..." if len(video['title']) > 35 else video['title']
            
            local_path = self.check_video_downloaded(video['bvid'])
            status = "📥" if local_path else "🌐"
            
            item = QListWidgetItem(f"{i}. {status} {title}")
            item.setData(Qt.UserRole, video)
            self.history_list.addItem(item)
    
    def on_history_clicked(self, item):
        video = item.data(Qt.UserRole)
        if video:
            self.current_video = video
            self.title_label.setText(video['title'])
            self.bvid_label.setText(f"BVID: {video['bvid']}")
            self.duration_label.setText(f"时长: {self.format_duration(video.get('duration'))}")
            
            local_path = self.check_video_downloaded(video['bvid'])
            if local_path:
                self.play_local_video(local_path)
            else:
                self.start_download(video['bvid'])
    
    def open_in_browser(self):
        if self.current_video:
            url = f"https://www.bilibili.com/video/{self.current_video['bvid']}"
            webbrowser.open(url)
    
    def copy_bvid(self):
        if self.current_video:
            cb = QApplication.clipboard()
            cb.setText(self.current_video['bvid'])
            self.statusBar().showMessage("BVID已复制到剪贴板")
    
    def closeEvent(self, event):
        if self.download_thread and self.download_thread.isRunning():
            self.download_thread.stop()
            self.download_thread.wait()
        self.media_player.stop()
        event.accept()
    
    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        
        splitter = QSplitter(Qt.Horizontal)
        
        left_panel = QWidget()
        left_layout = QVBoxLayout(left_panel)
        
        video_frame = QFrame()
        video_frame.setStyleSheet("background-color: #000; border-radius: 8px;")
        video_layout = QVBoxLayout(video_frame)
        video_layout.setContentsMargins(0, 0, 0, 0)
        
        video_container = QWidget()
        video_container.setStyleSheet("background-color: #000;")
        video_container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        
        video_layout.addWidget(self.video_widget)
        
        controls_frame = QFrame()
        controls_frame.setStyleSheet("background-color: rgba(0,0,0,0.5);")
        controls_layout = QHBoxLayout(controls_frame)
        
        self.btn_play = QPushButton("▶")
        self.btn_play.setStyleSheet("""
            QPushButton {
                background: rgba(255,255,255,0.2);
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 4px;
                font-size: 12px;
            }
            QPushButton:hover {
                background: rgba(255,255,255,0.3);
            }
        """)
        self.btn_play.clicked.connect(self.play_pause)
        controls_layout.addWidget(self.btn_play)
        
        self.slider_progress = QSlider(Qt.Horizontal)
        self.slider_progress.setStyleSheet("""
            QSlider::groove:horizontal {
                height: 6px;
                background: rgba(255,255,255,0.2);
                border-radius: 3px;
            }
            QSlider::handle:horizontal {
                width: 14px;
                height: 14px;
                background: #667eea;
                border-radius: 7px;
                margin: -4px 0;
            }
        """)
        self.slider_progress.sliderMoved.connect(self.set_position)
        controls_layout.addWidget(self.slider_progress)
        
        self.label_time = QLabel("00:00 / 00:00")
        self.label_time.setStyleSheet("color: white; font-size: 12px;")
        controls_layout.addWidget(self.label_time)
        
        video_layout.addWidget(controls_frame)
        left_layout.addWidget(video_frame)
        
        info_frame = QFrame()
        info_frame.setStyleSheet("background-color: rgba(255,255,255,0.05); border-radius: 8px;")
        info_layout = QVBoxLayout(info_frame)
        info_layout.setContentsMargins(15, 15, 15, 15)
        
        self.title_label = QLabel("等待抽选...")
        self.title_label.setStyleSheet("font-size: 16px; font-weight: bold; color: #fff;")
        self.title_label.setWordWrap(True)
        info_layout.addWidget(self.title_label)
        
        meta_layout = QHBoxLayout()
        
        self.bvid_label = QLabel("BVID: ")
        self.bvid_label.setStyleSheet("font-size: 12px; color: #667eea;")
        meta_layout.addWidget(self.bvid_label)
        
        self.duration_label = QLabel("时长: ")
        self.duration_label.setStyleSheet("font-size: 12px; color: #667eea;")
        meta_layout.addWidget(self.duration_label)
        
        self.count_label = QLabel(f"已抽选: 0 / {len(self.videos)}")
        self.count_label.setStyleSheet("font-size: 12px; color: #999;")
        meta_layout.addWidget(self.count_label)
        
        meta_layout.addStretch()
        info_layout.addLayout(meta_layout)
        
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setStyleSheet("""
            QProgressBar {
                border-radius: 10px;
                background-color: rgba(255,255,255,0.1);
            }
            QProgressBar::chunk {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #667eea, stop:1 #764ba2);
                border-radius: 10px;
            }
        """)
        info_layout.addWidget(self.progress_bar)
        
        btn_layout = QHBoxLayout()
        
        self.btn_pick = QPushButton("🎲 随机抽选")
        self.btn_pick.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #667eea, stop:1 #764ba2);
                color: white;
                border: none;
                padding: 10px 25px;
                border-radius: 20px;
                font-weight: bold;
                font-size: 14px;
            }
            QPushButton:hover {
                opacity: 0.9;
            }
        """)
        self.btn_pick.clicked.connect(self.pick_random)
        btn_layout.addWidget(self.btn_pick)
        
        btn_open = QPushButton("🔗 在B站打开")
        btn_open.setStyleSheet("""
            QPushButton {
                background: rgba(255,255,255,0.1);
                color: white;
                border: 1px solid rgba(255,255,255,0.2);
                padding: 10px 20px;
                border-radius: 20px;
            }
            QPushButton:hover {
                background: rgba(255,255,255,0.15);
            }
        """)
        btn_open.clicked.connect(self.open_in_browser)
        btn_layout.addWidget(btn_open)
        
        btn_copy = QPushButton("📋 复制BVID")
        btn_copy.setStyleSheet("""
            QPushButton {
                background: rgba(255,255,255,0.1);
                color: white;
                border: 1px solid rgba(255,255,255,0.2);
                padding: 10px 20px;
                border-radius: 20px;
            }
            QPushButton:hover {
                background: rgba(255,255,255,0.15);
            }
        """)
        btn_copy.clicked.connect(self.copy_bvid)
        btn_layout.addWidget(btn_copy)
        
        btn_layout.addStretch()
        info_layout.addLayout(btn_layout)
        
        left_layout.addWidget(info_frame)
        
        splitter.addWidget(left_panel)
        
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        
        history_label = QLabel("📜 抽选历史")
        history_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #999;")
        right_layout.addWidget(history_label)
        
        self.history_list = QListWidget()
        self.history_list.setStyleSheet("""
            QListWidget {
                background-color: rgba(255,255,255,0.05);
                border-radius: 8px;
                color: #ccc;
                font-size: 12px;
            }
            QListWidget::item:hover {
                background-color: rgba(255,255,255,0.1);
            }
        """)
        self.history_list.addItem("暂无抽选记录")
        self.history_list.itemClicked.connect(self.on_history_clicked)
        right_layout.addWidget(self.history_list)
        
        downloaded_label = QLabel("📥 已下载视频")
        downloaded_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #999;")
        right_layout.addWidget(downloaded_label)
        
        self.downloaded_list = QListWidget()
        self.downloaded_list.setStyleSheet("""
            QListWidget {
                background-color: rgba(255,255,255,0.05);
                border-radius: 8px;
                color: #ccc;
                font-size: 12px;
            }
            QListWidget::item:hover {
                background-color: rgba(255,255,255,0.1);
            }
        """)
        self.update_downloaded_list()
        self.downloaded_list.itemDoubleClicked.connect(self.on_downloaded_double_click)
        right_layout.addWidget(self.downloaded_list)
        
        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 1)
        
        main_layout.addWidget(splitter)
        
        central_widget.setStyleSheet("""
            QWidget {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #1a1a2e, stop:0.5 #16213e, stop:1 #0f3460);
            }
        """)
        
        self.setStatusBar(QStatusBar())
        self.statusBar().showMessage("就绪")
    
    def update_downloaded_list(self):
        self.downloaded_list.clear()
        for filename in sorted(os.listdir(self.download_dir)):
            if filename.endswith('.mp4'):
                item = QListWidgetItem(filename)
                item.setData(Qt.UserRole, os.path.join(self.download_dir, filename))
                self.downloaded_list.addItem(item)
    
    def on_downloaded_double_click(self, item):
        filepath = item.data(Qt.UserRole)
        if filepath:
            self.play_local_video(filepath)


if __name__ == '__main__':
    try:
        app = QApplication(sys.argv)
        window = RandomVideoPlayer()
        window.show()
        sys.exit(app.exec_())
    except Exception as e:
        QMessageBox.critical(None, "程序崩溃", str(e))
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()