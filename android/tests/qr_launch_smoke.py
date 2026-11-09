"""真机二维码调起回归；会重启应用并将目标地址设置为传入 URL，不用于活动传输期间。"""
import subprocess
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET


def main():
    if len(sys.argv) != 3:
        raise SystemExit("用法: python3 android/tests/qr_launch_smoke.py <adb-serial> <target-url>")
    serial, target = sys.argv[1:]
    link = "androidsync://configure?url=" + urllib.parse.quote(target, safe="")

    def adb(*args):
        return subprocess.run(
            ["adb", "-s", serial, *args], check=True,
            capture_output=True, text=True, timeout=30,
        ).stdout

    def assert_settings():
        # 等待生命周期和 onStart 更新执行；am start -W 的成功本身不能证明未闪退。
        time.sleep(1)
        pid = adb("shell", "pidof", "com.androidsync.app").strip()
        if not pid:
            raise AssertionError("调起后应用进程不存在")
        path = "/data/local/tmp/android-sync-qr-smoke.xml"
        adb("shell", "uiautomator", "dump", path)
        try:
            tree = ET.fromstring(adb("shell", "cat", path))
        finally:
            adb("shell", "rm", "-f", path)
        labels = {node.get("text") for node in tree.iter("node")}
        if "接收端" not in labels or target not in labels:
            raise AssertionError("未显示接收地址设置页或地址不匹配")
        if adb("shell", "pidof", "com.androidsync.app").strip() != pid:
            raise AssertionError("检查期间应用进程发生重启")
        return pid

    def open_link(cold=False):
        args = ["shell", "am", "start", "-W"]
        if cold:
            args.append("-S")
        adb(*args, "-a", "android.intent.action.VIEW", "-d", link,
            "-p", "com.androidsync.app")
        return assert_settings()

    cold_pid = open_link(cold=True)
    print("PASS: 二维码深链冷启动进入设置页", flush=True)
    if open_link() != cold_pid:
        raise AssertionError("前台再次调起未保留进程")
    print("PASS: 设置页前台再次调起", flush=True)
    adb("shell", "am", "start", "-W", "-S", "-n", "com.androidsync.app/.MainActivity")
    time.sleep(1)
    library_pid = adb("shell", "pidof", "com.androidsync.app").strip()
    if open_link() != library_pid:
        raise AssertionError("媒体库前台调起未保留进程")
    print("PASS: 媒体库前台调起进入设置页", flush=True)


if __name__ == "__main__":
    main()
