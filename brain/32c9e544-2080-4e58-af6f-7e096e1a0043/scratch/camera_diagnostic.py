import cv2
import time

def list_cameras():
    print("Listing available cameras...")
    for i in range(5):
        cap = cv2.VideoCapture(i, cv2.CAP_DSHOW) if cv2.os.name == 'nt' else cv2.VideoCapture(i)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret:
                print(f"Index {i}: WORKING")
                # Show a temporary preview to help user identify
                win_name = f"Camera Index {i}"
                cv2.imshow(win_name, frame)
                cv2.waitKey(2000) # Show for 2 seconds
                cv2.destroyWindow(win_name)
            else:
                print(f"Index {i}: OPENED BUT NO FRAME")
            cap.release()
        else:
            print(f"Index {i}: NOT FOUND")

if __name__ == "__main__":
    list_cameras()
