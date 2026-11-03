// Keep audio examples mutually exclusive without adding external dependencies.
document.querySelectorAll('audio').forEach((player) => {
  player.addEventListener('play', () => {
    document.querySelectorAll('audio').forEach((other) => {
      if (other !== player) other.pause();
    });
  });
});
