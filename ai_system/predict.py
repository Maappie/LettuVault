import os
import cv2
from ultralytics import YOLO

def run_live_camera():
    # 1. Define the path to your best model (v12)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(script_dir, 'runs', 'lettuce_strawberry_v12', 'weights', 'best.pt')

    if not os.path.exists(model_path):
        print(f"❌ Error: Model not found at {model_path}")
        return

    # 2. Load the model
    print(f"🧠 Loading model: {model_path}")
    model = YOLO(model_path)

    # 3. Open the Webcam (0 is usually the built-in laptop camera)
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("❌ Error: Could not open webcam.")
        return

    print("🚀 Camera is LIVE! Press 'q' to quit.")

    while True:
        # Capture frame-by-frame
        success, frame = cap.read()

        if not success:
            break

        # Run YOLOv8 inference on the frame
        # stream=True makes it faster for live video
        results = model.predict(source=frame, conf=0.3, show=False, stream=True)

        # Draw the results on the frame
        for r in results:
            annotated_frame = r.plot()

        # Display the resulting frame
        cv2.imshow("LettuVault Live AI Detection", annotated_frame)

        # Break the loop if 'q' is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Clean up
    cap.release()
    cv2.destroyAllWindows()
    print("👋 Camera closed.")

if __name__ == "__main__":
    run_live_camera()