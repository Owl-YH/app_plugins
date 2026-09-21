/// 从累计目标时间取相邻差值，避免反复舍入 1/fps 丢失微秒。
Duration elapsedForFrame(int frame, int framesPerSecond) {
  int boundary(int index) =>
      (index * Duration.microsecondsPerSecond + framesPerSecond - 1) ~/
      framesPerSecond;
  return Duration(microseconds: boundary(frame + 1) - boundary(frame));
}
