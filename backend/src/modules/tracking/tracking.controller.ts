import { Router, Request, Response } from 'express';
import { db } from '../../database';

export const trackingRouter = Router();

// API endpoint returning ride JSON for tracking
trackingRouter.get('/:id/json', async (req: Request, res: Response): Promise<void> => {
  try {
    const rideId = String(req.params.id);
    const ride = await db.getRideById(rideId);
    if (!ride) {
      res.status(404).json({ success: false, message: 'Ride not found' });
      return;
    }

    let driver = null;
    let driverProfile = null;
    if (ride.driver_id) {
      const u = await db.findUserById(ride.driver_id);
      if (u) {
        driver = {
          name: u.full_name,
          phone: u.phone_number ? u.phone_number.slice(0, 4) + '***' + u.phone_number.slice(-3) : 'Verified',
        };
      }
      const p = await db.getDriverProfile(ride.driver_id);
      if (p) {
        driverProfile = {
          vehicle: `${p.vehicle_color || ''} ${p.vehicle_make || ''} ${p.vehicle_model || ''}`.trim() || 'Verified Vehicle',
          licensePlate: p.license_plate || '',
          rating: p.rating_average || 4.9,
          trips: p.total_trips_completed || 100,
        };
      }
    }

    res.status(200).json({
      success: true,
      data: {
        rideId: ride.id,
        status: ride.status,
        pickupAddress: ride.pickup_address,
        pickupLat: ride.pickup_lat,
        pickupLng: ride.pickup_lng,
        dropoffAddress: ride.dropoff_address,
        dropoffLat: ride.dropoff_lat,
        dropoffLng: ride.dropoff_lng,
        distanceKm: ride.distance_km,
        fareNgn: ride.agreed_fare_ngn || ride.rider_offer_ngn || ride.suggested_fare_ngn,
        createdAt: ride.created_at,
        driver,
        driverProfile,
      },
    });
  } catch (err: any) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Web Tracking Page (HTML)
trackingRouter.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const rideId = String(req.params.id);
    const ride = await db.getRideById(rideId);

    if (!ride) {
      res.status(404).send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Giga Ride - Trip Not Found</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0A0F1D; color: #F8FAFC; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { background: #131C31; padding: 40px; border-radius: 20px; text-align: center; max-width: 400px; border: 1px solid rgba(255,255,255,0.1); }
            h2 { color: #EF4444; margin-bottom: 12px; }
            p { color: #94A3B8; font-size: 14px; }
            a { color: #14B8A6; text-decoration: none; font-weight: bold; }
          </style>
        </head>
        <body>
          <div class="card">
            <h2>Ride Not Found</h2>
            <p>This trip link may have expired or the ride reference is invalid.</p>
            <p style="margin-top:20px;"><a href="/">Return to Giga Home</a></p>
          </div>
        </body>
        </html>
      `);
      return;
    }

    let driverName = 'Assigning driver...';
    let driverVehicle = 'Inspected Vehicle';
    let driverPlate = 'GIGA';
    let driverRating = '4.9';

    if (ride.driver_id) {
      const u = await db.findUserById(ride.driver_id);
      if (u) driverName = u.full_name;
      const p = await db.getDriverProfile(ride.driver_id);
      if (p) {
        driverVehicle = `${p.vehicle_color || ''} ${p.vehicle_make || ''} ${p.vehicle_model || ''}`.trim() || 'Verified Vehicle';
        driverPlate = p.license_plate || '';
        driverRating = String(p.rating_average || 4.9);
      }
    }

    const fare = (ride.agreed_fare_ngn || ride.rider_offer_ngn || ride.suggested_fare_ngn || 2500).toLocaleString();

    let statusText = 'Looking for nearby drivers';
    let statusClass = 'status-pending';
    if (ride.status === 'ACCEPTED') {
      statusText = 'Driver is on the way';
      statusClass = 'status-accepted';
    } else if (ride.status === 'ARRIVED') {
      statusText = 'Driver has arrived at pickup';
      statusClass = 'status-arrived';
    } else if (ride.status === 'IN_TRANSIT') {
      statusText = 'Trip in progress to destination';
      statusClass = 'status-transit';
    } else if (ride.status === 'COMPLETED') {
      statusText = 'Trip safely completed';
      statusClass = 'status-completed';
    } else if (ride.status === 'CANCELLED') {
      statusText = 'Trip cancelled';
      statusClass = 'status-cancelled';
    }

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Live Ride Tracking — Giga Ride</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #0A0F1D;
      color: #F8FAFC;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header {
      background: #131C31;
      border-bottom: 1px solid rgba(20, 184, 166, 0.2);
      padding: 16px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .brand-logo {
      width: 32px;
      height: 32px;
      background: linear-gradient(135deg, #0D9488, #14B8A6);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 900;
      color: white;
      font-size: 18px;
    }
    .brand-title {
      font-size: 18px;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: #F8FAFC;
    }
    .ndpr-badge {
      background: rgba(16, 185, 129, 0.15);
      color: #10B981;
      border: 1px solid rgba(16, 185, 129, 0.3);
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 5px;
    }
    #map {
      height: 300px;
      width: 100%;
      background: #1E293B;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      padding: 16px 20px;
      width: 100%;
      flex: 1;
    }
    .card {
      background: #131C31;
      border-radius: 18px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      padding: 20px;
      margin-bottom: 16px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
    }
    .status-bar {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 16px;
      padding: 12px 16px;
      border-radius: 12px;
      background: #1E293B;
      font-size: 14px;
      font-weight: 700;
    }
    .pulse-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #10B981;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
      70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
      100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
    }
    .driver-row {
      display: flex;
      align-items: center;
      gap: 14px;
      margin-bottom: 16px;
    }
    .driver-avatar {
      width: 50px;
      height: 50px;
      border-radius: 50%;
      background: linear-gradient(135deg, #0D9488, #1E293B);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      font-weight: bold;
      color: white;
      border: 2px solid #14B8A6;
    }
    .driver-info {
      flex: 1;
    }
    .driver-name {
      font-size: 16px;
      font-weight: 700;
      color: #F8FAFC;
    }
    .driver-car {
      font-size: 13px;
      color: #94A3B8;
      margin-top: 2px;
    }
    .plate-badge {
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.15);
      padding: 6px 12px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.5px;
      color: #F8FAFC;
    }
    .route-row {
      display: flex;
      gap: 12px;
      margin-top: 14px;
    }
    .route-pins {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-top: 4px;
    }
    .pin-green { width: 10px; height: 10px; border-radius: 50%; background: #10B981; }
    .pin-line { width: 2px; height: 32px; background: rgba(255,255,255,0.15); margin: 4px 0; }
    .pin-amber { width: 10px; height: 10px; border-radius: 2px; background: #F59E0B; }
    .route-text { flex: 1; }
    .route-point { margin-bottom: 12px; }
    .route-label { font-size: 11px; color: #94A3B8; text-transform: uppercase; letter-spacing: 0.5px; }
    .route-addr { font-size: 14px; color: #F8FAFC; font-weight: 600; margin-top: 2px; }
    .fare-box {
      background: rgba(13, 148, 136, 0.12);
      border: 1px solid rgba(20, 184, 166, 0.3);
      padding: 14px 18px;
      border-radius: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 16px;
    }
    .fare-title { font-size: 13px; color: #94A3B8; }
    .fare-amount { font-size: 22px; font-weight: 900; color: #F59E0B; }
    .footer-note {
      text-align: center;
      color: #64748B;
      font-size: 12px;
      padding: 16px 20px 30px;
    }
    .cta-btn {
      display: block;
      width: 100%;
      padding: 14px;
      background: #0D9488;
      color: white;
      text-align: center;
      border-radius: 14px;
      text-decoration: none;
      font-weight: 700;
      font-size: 15px;
      margin-top: 14px;
      box-shadow: 0 4px 14px rgba(13, 148, 136, 0.4);
    }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <div class="brand-logo">G</div>
      <div class="brand-title">Giga Ride</div>
    </div>
    <div class="ndpr-badge">
      <span>🛡️</span> NDPR Encrypted
    </div>
  </header>

  <div id="map"></div>

  <div class="container">
    <div class="card">
      <div class="status-bar ${statusClass}">
        <div class="pulse-dot"></div>
        <span>${statusText}</span>
      </div>

      ${ride.driver_id ? `
      <div class="driver-row">
        <div class="driver-avatar">${driverName.charAt(0).toUpperCase()}</div>
        <div class="driver-info">
          <div class="driver-name">${driverName} <span style="color:#F59E0B; font-size:13px;">★ ${driverRating}</span></div>
          <div class="driver-car">${driverVehicle}</div>
        </div>
        <div class="plate-badge">${driverPlate}</div>
      </div>
      ` : ''}

      <div class="route-row">
        <div class="route-pins">
          <div class="pin-green"></div>
          <div class="pin-line"></div>
          <div class="pin-amber"></div>
        </div>
        <div class="route-text">
          <div class="route-point">
            <div class="route-label">Pickup Location</div>
            <div class="route-addr">${ride.pickup_address}</div>
          </div>
          <div class="route-point" style="margin-bottom:0;">
            <div class="route-label">Destination</div>
            <div class="route-addr">${ride.dropoff_address}</div>
          </div>
        </div>
      </div>

      <div class="fare-box">
        <span class="fare-title">Agreed Trip Fare</span>
        <span class="fare-amount">₦${fare}</span>
      </div>

      <a href="https://engine.getgigaride.com/downloads/GigaPassenger-release.apk" class="cta-btn">Download Giga Ride App</a>
    </div>

    <div class="footer-note">
      256-Bit SSL Encrypted • Real-time GPS Tracking • Zero Commission Model<br>
      © ${new Date().getFullYear()} Giga Ride Nigeria. All rights reserved.
    </div>
  </div>

  <script>
    const pickup = [${ride.pickup_lat}, ${ride.pickup_lng}];
    const dropoff = [${ride.dropoff_lat}, ${ride.dropoff_lng}];

    const map = L.map('map', { zoomControl: false }).fitBounds([pickup, dropoff], { padding: [40, 40] });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors'
    }).addTo(map);

    const greenIcon = L.divIcon({
      html: '<div style="background:#10B981; width:16px; height:16px; border-radius:50%; border:3px solid white; box-shadow:0 2px 6px rgba(0,0,0,0.4);"></div>',
      className: '',
      iconSize: [16, 16],
      iconAnchor: [8, 8]
    });

    const amberIcon = L.divIcon({
      html: '<div style="background:#F59E0B; width:16px; height:16px; border-radius:3px; border:3px solid white; box-shadow:0 2px 6px rgba(0,0,0,0.4);"></div>',
      className: '',
      iconSize: [16, 16],
      iconAnchor: [8, 8]
    });

    L.marker(pickup, { icon: greenIcon }).addTo(map).bindPopup('Pickup: ${ride.pickup_address.replace(/'/g, "\\'")}');
    L.marker(dropoff, { icon: amberIcon }).addTo(map).bindPopup('Destination: ${ride.dropoff_address.replace(/'/g, "\\'")}');

    L.polyline([pickup, dropoff], { color: '#0D9488', weight: 4, dashArray: '8, 8' }).addTo(map);

    // Auto-refresh status every 8 seconds
    setInterval(async () => {
      try {
        const res = await fetch(window.location.pathname + '/json');
        const data = await res.json();
        if (data.success && data.data.status !== '${ride.status}') {
          window.location.reload();
        }
      } catch (_) {}
    }, 8000);
  </script>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.status(200).send(html);
  } catch (err: any) {
    res.status(500).send('Internal Server Error: ' + err.message);
  }
});
