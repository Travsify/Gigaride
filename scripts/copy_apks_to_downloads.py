import os
import shutil

downloads = os.path.expanduser('~\\Downloads')

# Source APKs
passenger_src = r'c:\Users\USER\Desktop\giga\apps\passenger_app\build\app\outputs\flutter-apk\app-debug.apk'
driver_src = r'c:\Users\USER\Desktop\giga\apps\driver_app\build\app\outputs\flutter-apk\app-debug.apk'

# Dedicated folders in Downloads
passenger_folder = os.path.join(downloads, 'GigaRide_Passenger')
driver_folder = os.path.join(downloads, 'GigaRide_Driver')

os.makedirs(passenger_folder, exist_ok=True)
os.makedirs(driver_folder, exist_ok=True)

targets = [
    # Dedicated respective folders
    (passenger_src, os.path.join(passenger_folder, 'GigaRide-Passenger.apk')),
    (driver_src, os.path.join(driver_folder, 'GigaRide-Driver.apk')),
    # Root of Downloads for instant 1-click access
    (passenger_src, os.path.join(downloads, 'GigaRide-Passenger.apk')),
    (passenger_src, os.path.join(downloads, 'GigaPassenger-release.apk')),
    (driver_src, os.path.join(downloads, 'GigaRide-Driver.apk')),
    (driver_src, os.path.join(downloads, 'GigaDriver-release.apk')),
]

print('=== Deploying Updated APKs to Downloads ===')
for src, dst in targets:
    if os.path.exists(src):
        shutil.copy2(src, dst)
        size_mb = os.path.getsize(dst) / (1024 * 1024)
        print(f'[OK] Copied ({size_mb:.1f} MB) -> {dst}')
    else:
        print(f'[MISSING] Source not found: {src}')

print('\nAll APKs updated in Downloads successfully!')
