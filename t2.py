import os
import whisper
import time
from pydub import AudioSegment
import argparse
import warnings
from urllib.error import URLError

def download_whisper_model(model_size="base", retries=3):
    """
    Download Whisper model with retry logic and progress display
    """
    for attempt in range(retries):
        try:
            # Suppress the checksum warning since we're handling it
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                print(f"Downloading Whisper {model_size} model (attempt {attempt + 1}/{retries})...")
                start_time = time.time()
                model = whisper.load_model(model_size, download_root="./whisper_models")
                print(f"Model downloaded and loaded in {time.time() - start_time:.2f} seconds")
                return model
        except URLError as e:
            print(f"Download failed: {str(e)}")
            if attempt < retries - 1:
                print("Retrying...")
                time.sleep(2)  # Wait before retrying
            else:
                raise RuntimeError(f"Failed to download model after {retries} attempts")

def transcribe_with_whisper(audio_file_path, output_txt_path=None, model_size="base"):
    """
    Transcribes WhatsApp voice note using Whisper AI with robust error handling
    """
    if not os.path.exists(audio_file_path):
        raise FileNotFoundError(f"Audio file not found: {audio_file_path}")

    try:
        # Create directory for models if it doesn't exist
        os.makedirs("./whisper_models", exist_ok=True)

        # Load model with download retry logic
        model = download_whisper_model(model_size)

        # Convert audio to WAV format (better compatibility)
        try:
            audio = AudioSegment.from_file(audio_file_path)
            wav_path = "temp_whisper.wav"
            audio.export(wav_path, format="wav")
        except Exception as e:
            raise RuntimeError(f"Audio conversion failed: {str(e)}")

        # Perform transcription
        print("Starting transcription...")
        start_time = time.time()
        try:
            result = model.transcribe(wav_path)
            transcription = result["text"]
            print(f"Transcription completed in {time.time() - start_time:.2f} seconds")
        except Exception as e:
            raise RuntimeError(f"Transcription failed: {str(e)}")
        finally:
            # Clean up temporary file
            if os.path.exists(wav_path):
                os.remove(wav_path)

        # Handle output
        if output_txt_path:
            try:
                with open(output_txt_path, 'w', encoding='utf-8') as f:
                    f.write(transcription)
                print(f"\nTranscription saved to {output_txt_path}")
            except IOError as e:
                print(f"\nWarning: Could not save to file - {str(e)}")
                print("\nTranscription Result:")
                print("-" * 50)
                print(transcription)
                print("-" * 50)
        else:
            print("\nTranscription Result:")
            print("-" * 50)
            print(transcription)
            print("-" * 50)

        return transcription

    except Exception as e:
        print(f"\nError: {str(e)}")
        return None

def main():
    print("\nWhatsApp Voice Note Transcription with Whisper AI")
    print("----------------------------------------------")

    parser = argparse.ArgumentParser(description="Transcribe WhatsApp voice notes using Whisper AI")
    parser.add_argument("audio_file", help="Path to the WhatsApp voice note audio file")
    parser.add_argument("-o", "--output", help="Path to save the transcription text file")
    parser.add_argument("-m", "--model", default="base",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size (default: base)")
    
    args = parser.parse_args()

    transcribe_with_whisper(
        audio_file_path=args.audio_file,
        output_txt_path=args.output,
        model_size=args.model
    )

if __name__ == "__main__":
    main()
