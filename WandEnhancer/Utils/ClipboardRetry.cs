using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;

namespace WandEnhancer.Utils
{
    /// <summary>
    /// Provides safe clipboard manipulation with backoff retries to prevent
    /// CLIPBRD_E_CANT_OPEN (0x800401D0) exceptions caused by other background
    /// processes (e.g. clipboard managers, Office, Remote Desktop) briefly locking the clipboard.
    /// </summary>
    public static class ClipboardRetry
    {
        private const int DefaultMaxRetries = 5;
        private const int DefaultDelayMs = 100;
        private const int ErrorClipbrdECantOpen = unchecked((int)0x800401D0);

        /// <summary>
        /// Attempts to set text to the clipboard, retrying if the clipboard is locked.
        /// </summary>
        /// <param name="text">The text to copy to the clipboard.</param>
        /// <param name="maxRetries">Maximum retry attempts.</param>
        /// <param name="delayMs">Delay between retry attempts in milliseconds.</param>
        public static void SetText(string text, int maxRetries = DefaultMaxRetries, int delayMs = DefaultDelayMs)
        {
            if (text == null)
            {
                throw new ArgumentNullException(nameof(text));
            }

            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    Clipboard.SetText(text);
                    return;
                }
                catch (COMException ex) when (ex.ErrorCode == ErrorClipbrdECantOpen && attempt < maxRetries)
                {
                    Thread.Sleep(delayMs);
                }
                catch (Exception) when (attempt < maxRetries)
                {
                    Thread.Sleep(delayMs);
                }
            }
        }
    }
}
