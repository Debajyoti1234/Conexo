import https from 'node:https';
import http from 'node:http';
import { randomUUID } from 'node:crypto';

const SUPABASE_URL = 'https://wlfitdzhvfhuqgxwreed.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_SERVICE_ROLE_KEY environment variable');
  process.exit(1);
}

const DEMO_USERS = [
  {
    email: 'demo-maya@conexo.app',
    password: 'DemoPass123!',
    name: 'Maya',
    displayName: 'Maya',
    gender: 'Woman',
    dob: '1998-03-15',
    bio: 'Recently moved for a new job and slowly turning this city into home. I love quiet cafes, golden-hour light, and long unhurried talks.',
    interests: ['Photography', 'Coffee', 'Slow travel'],
    languages: ['English', 'Hindi', 'Kannada'],
    location: 'Bengaluru • Indiranagar',
    occupation: 'Product Designer',
    verification: 'verified',
    availability: 'available_now',
    lat: 12.9716,
    lng: 77.5946,
    created_at: '2026-07-01T00:00:00Z',
  },
  {
    email: 'demo-arjun@conexo.app',
    password: 'DemoPass123!',
    name: 'Arjun',
    displayName: 'Arjun',
    gender: 'Man',
    dob: '1997-08-22',
    bio: 'Vinyl collector and part-time daydreamer. I believe the best evenings start with a good record and end with a real conversation.',
    interests: ['Music', 'Walking', 'Books'],
    languages: ['English', 'Hindi', 'Tamil'],
    location: 'Bengaluru • Koramangala',
    occupation: 'Sound Engineer',
    verification: 'verified',
    availability: 'available_now',
    lat: 12.9352,
    lng: 77.6246,
    created_at: '2026-07-05T00:00:00Z',
  },
  {
    email: 'demo-nora@conexo.app',
    password: 'DemoPass123!',
    name: 'Nora',
    displayName: 'Nora',
    gender: 'Woman',
    dob: '1999-11-30',
    bio: 'Street photographer by passion, illustrator by trade. I collect quiet mornings, film cameras, and honest conversations.',
    interests: ['Photography', 'Art', 'Cafes'],
    languages: ['English', 'Hindi', 'Marathi'],
    location: 'Mumbai • Bandra',
    occupation: 'Illustrator',
    verification: 'verified',
    availability: 'available_now',
    lat: 19.0544,
    lng: 72.8402,
    created_at: '2026-07-10T00:00:00Z',
  },
  {
    email: 'demo-kabir@conexo.app',
    password: 'DemoPass123!',
    name: 'Kabir',
    displayName: 'Kabir',
    gender: 'Man',
    dob: '1996-05-18',
    bio: 'Software engineer who unplugs on mountain trails. I cook a mean ramen and take my board-game nights a little too seriously.',
    interests: ['Running', 'Gaming', 'Cooking'],
    languages: ['English', 'Hindi', 'Punjabi'],
    location: 'Pune • Kalyani Nagar',
    occupation: 'Backend Engineer',
    verification: 'notVerified',
    availability: 'available_now',
    lat: 18.5204,
    lng: 73.8567,
    created_at: '2026-06-20T00:00:00Z',
  },
  {
    email: 'demo-aisha@conexo.app',
    password: 'DemoPass123!',
    name: 'Aisha',
    displayName: 'Aisha',
    gender: 'Woman',
    dob: '2000-01-09',
    bio: 'Content writer with a shelf that keeps outgrowing my apartment. I bake when I think, and I think out loud over chai.',
    interests: ['Reading', 'Poetry', 'Baking'],
    languages: ['English', 'Hindi', 'Urdu'],
    location: 'Delhi • Hauz Khas',
    occupation: 'Content Writer',
    verification: 'verified',
    availability: 'available_now',
    lat: 28.5494,
    lng: 77.1944,
    created_at: '2026-07-15T00:00:00Z',
  },
  {
    email: 'demo-dev@conexo.app',
    password: 'DemoPass123!',
    name: 'Dev',
    displayName: 'Dev',
    gender: 'Man',
    dob: '1995-12-01',
    bio: 'Marketing lead who plans weekend rides around the best breakfast spots. Always up for a spontaneous road trip.',
    interests: ['Cycling', 'Food', 'Travel'],
    languages: ['English', 'Hindi', 'Telugu'],
    location: 'Hyderabad • Jubilee Hills',
    occupation: 'Marketing Lead',
    verification: 'notVerified',
    availability: 'available_now',
    lat: 17.3850,
    lng: 78.4867,
    created_at: '2026-06-25T00:00:00Z',
  },
  {
    email: 'demo-sara@conexo.app',
    password: 'DemoPass123!',
    name: 'Sara',
    displayName: 'Sara',
    gender: 'Woman',
    dob: '2001-07-14',
    bio: 'Contemporary dancer teaching weekend classes. My apartment is basically a small jungle and I would not have it any other way.',
    interests: ['Dance', 'Plants', 'Music'],
    languages: ['English', 'Hindi', 'Kannada'],
    location: 'Bengaluru • HSR Layout',
    occupation: 'Dance Instructor',
    verification: 'verified',
    availability: 'available_now',
    lat: 12.9116,
    lng: 77.6472,
    created_at: '2026-07-20T00:00:00Z',
  },
  {
    email: 'demo-rehan@conexo.app',
    password: 'DemoPass123!',
    name: 'Rehan',
    displayName: 'Rehan',
    gender: 'Man',
    dob: '1994-04-03',
    bio: 'Barista turned cafe owner. I brew single-origin pour-overs and love a good debate about almost anything.',
    interests: ['Coffee', 'Chess', 'Podcasts'],
    languages: ['English', 'Hindi', 'Tamil'],
    location: 'Chennai • Nungambakkam',
    occupation: 'Cafe Owner',
    verification: 'verified',
    availability: 'available_now',
    lat: 13.0827,
    lng: 80.2707,
    created_at: '2026-06-15T00:00:00Z',
  },
  {
    email: 'demo-ananya@conexo.app',
    password: 'DemoPass123!',
    name: 'Ananya',
    displayName: 'Ananya',
    gender: 'Woman',
    dob: '1999-09-25',
    bio: 'Wellness coach learning to slow down. I paint with watercolors and believe mornings should never be rushed.',
    interests: ['Yoga', 'Art', 'Journaling'],
    languages: ['English', 'Hindi', 'Konkani'],
    location: 'Goa • Assagao',
    occupation: 'Wellness Coach',
    verification: 'notVerified',
    availability: 'available_now',
    lat: 15.2993,
    lng: 74.1240,
    created_at: '2026-07-25T00:00:00Z',
  },
  {
    email: 'demo-vikram@conexo.app',
    password: 'DemoPass123!',
    name: 'Vikram',
    displayName: 'Vikram',
    gender: 'Man',
    dob: '1993-02-10',
    bio: 'Architect who escapes to the Himalayas every chance I get. My phone is 80 percent mountain photos and I am not sorry.',
    interests: ['Hiking', 'Photography', 'Camping'],
    languages: ['English', 'Hindi', 'Garhwali'],
    location: 'Dehradun • Rajpur Road',
    occupation: 'Architect',
    verification: 'verified',
    availability: 'available_now',
    lat: 30.3165,
    lng: 78.0322,
    created_at: '2026-06-10T00:00:00Z',
  },
  {
    email: 'demo-zoya@conexo.app',
    password: 'DemoPass123!',
    name: 'Zoya',
    displayName: 'Zoya',
    gender: 'Woman',
    dob: '2000-06-18',
    bio: 'Indie singer-songwriter recording in my bedroom studio. I thrift vintage jackets and hum melodies on the metro.',
    interests: ['Music', 'Singing', 'Thrifting'],
    languages: ['English', 'Hindi', 'Bengali'],
    location: 'Kolkata • Park Street',
    occupation: 'Musician',
    verification: 'verified',
    availability: 'available_now',
    lat: 22.5726,
    lng: 88.3639,
    created_at: '2026-07-18T00:00:00Z',
  },
  {
    email: 'demo-ishan@conexo.app',
    password: 'DemoPass123!',
    name: 'Ishan',
    displayName: 'Ishan',
    gender: 'Man',
    dob: '1996-10-05',
    bio: 'Building a small fintech and eating my way through every food street in town. Sunday football is non-negotiable.',
    interests: ['Food', 'Startups', 'Football'],
    languages: ['English', 'Hindi', 'Kannada'],
    location: 'Bengaluru • Whitefield',
    occupation: 'Founder',
    verification: 'notVerified',
    availability: 'available_now',
    lat: 12.9698,
    lng: 77.7500,
    created_at: '2026-07-22T00:00:00Z',
  },
  {
    email: 'demo-meera@conexo.app',
    password: 'DemoPass123!',
    name: 'Meera',
    displayName: 'Meera',
    gender: 'Woman',
    dob: '1998-12-12',
    bio: 'Screenwriter chasing stories in everyday people. I could talk about films for hours and never run out of recommendations.',
    interests: ['Cinema', 'Coffee', 'Writing'],
    languages: ['English', 'Hindi', 'Marathi'],
    location: 'Mumbai • Andheri',
    occupation: 'Screenwriter',
    verification: 'verified',
    availability: 'available_now',
    lat: 19.1136,
    lng: 72.8697,
    created_at: '2026-07-12T00:00:00Z',
  },
  {
    email: 'demo-aryan@conexo.app',
    password: 'DemoPass123!',
    name: 'Aryan',
    displayName: 'Aryan',
    gender: 'Man',
    dob: '1999-03-28',
    bio: 'Graphic designer who lives for the ocean. I skate to work and chase waves whenever the coast calls.',
    interests: ['Surfing', 'Skating', 'Design'],
    languages: ['English', 'Hindi', 'Konkani'],
    location: 'Goa • Vagator',
    occupation: 'Graphic Designer',
    verification: 'notVerified',
    availability: 'available_now',
    lat: 15.5964,
    lng: 73.7415,
    created_at: '2026-07-28T00:00:00Z',
  },
  {
    email: 'demo-tara@conexo.app',
    password: 'DemoPass123!',
    name: 'Tara',
    displayName: 'Tara',
    gender: 'Woman',
    dob: '1997-08-08',
    bio: 'Landscape designer turning balconies into little forests. I host slow dinners and believe plants make better neighbours.',
    interests: ['Gardening', 'Art', 'Cooking'],
    languages: ['English', 'Hindi', 'Punjabi'],
    location: 'Delhi • Saket',
    occupation: 'Landscape Designer',
    verification: 'verified',
    availability: 'available_now',
    lat: 28.5244,
    lng: 77.2066,
    created_at: '2026-07-08T00:00:00Z',
  },
  {
    email: 'demo-rohan@conexo.app',
    password: 'DemoPass123!',
    name: 'Rohan',
    displayName: 'Rohan',
    gender: 'Man',
    dob: '1992-11-20',
    bio: 'Doctor who runs to think and reads to slow down. I am training for a marathon and always looking for a decent bookshop.',
    interests: ['Running', 'Books', 'Coffee'],
    languages: ['English', 'Hindi', 'Kannada'],
    location: 'Bengaluru • Jayanagar',
    occupation: 'Physician',
    verification: 'verified',
    availability: 'available_now',
    lat: 12.9250,
    lng: 77.5938,
    created_at: '2026-06-18T00:00:00Z',
  },
  {
    email: 'demo-naina@conexo.app',
    password: 'DemoPass123!',
    name: 'Naina',
    displayName: 'Naina',
    gender: 'Woman',
    dob: '2001-04-15',
    bio: 'Street artist and part-time barista. I chase blank walls and good light, and I never travel without my paints.',
    interests: ['Art', 'Music', 'Travel'],
    languages: ['English', 'Hindi', 'Rajasthani'],
    location: 'Jaipur • C-Scheme',
    occupation: 'Muralist',
    verification: 'notVerified',
    availability: 'available_now',
    lat: 26.9124,
    lng: 75.7873,
    created_at: '2026-07-30T00:00:00Z',
  },
  {
    email: 'demo-karan@conexo.app',
    password: 'DemoPass123!',
    name: 'Karan',
    displayName: 'Karan',
    gender: 'Man',
    dob: '1996-09-09',
    bio: 'Chef who unwinds with jazz and a slow home brew. Give me an open road and a good playlist and I am the happiest person alive.',
    interests: ['Music', 'Cooking', 'Long drives'],
    languages: ['English', 'Hindi', 'Punjabi'],
    location: 'Chandigarh • Sector 9',
    occupation: 'Chef',
    verification: 'verified',
    availability: 'available_now',
    lat: 30.7333,
    lng: 76.7794,
    created_at: '2026-06-22T00:00:00Z',
  },
];

function request(method, path, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(SUPABASE_URL);
    const options = {
      hostname: url.hostname,
      path,
      method,
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey': SERVICE_ROLE_KEY,
        'Content-Type': 'application/json',
      },
    };
    const lib = url.protocol === 'https:' ? https : http;
    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function createDemoUsers() {
  console.log(`Seeding ${DEMO_USERS.length} demo users...\n`);

  for (const user of DEMO_USERS) {
    let userId = null;

    try {
      const authRes = await request('POST', '/auth/v1/admin/users', {
        email: user.email,
        password: user.password,
        email_confirm: true,
        user_metadata: { name: user.name },
      });

      if (authRes.status === 200 || authRes.status === 201) {
        userId = authRes.body.id;
        console.log(`Created auth user: ${user.email} -> ${userId}`);
      } else if (authRes.body?.error_code === 'email_exists') {
        console.log(`Auth user exists: ${user.email}, looking up...`);
        const listRes = await request('GET', `/auth/v1/admin/users?email=${encodeURIComponent(user.email)}`);
        const found = (listRes.body?.users || []).find((u) => u.email === user.email);
        if (found) {
          userId = found.id;
          console.log(`Found auth user: ${user.email} -> ${userId}`);
        } else {
          console.error(`Could not find existing user ${user.email}`);
          continue;
        }
      } else {
        console.error(`Failed to create auth user ${user.email}:`, authRes.status, authRes.body);
        continue;
      }
    } catch (err) {
      console.error(`Error creating auth user ${user.email}:`, err.message);
      continue;
    }

    if (!userId) continue;

    try {
      const profileRes = await request('POST', '/rest/v1/profiles', {
        id: userId,
        display_name: user.displayName,
        gender: user.gender,
        profile_visibility: 'public',
        profile_completed: true,
        date_of_birth: user.dob,
        photos: [
          {
            id: `demo_${userId.slice(0, 8)}`,
            assetPath: `assets/images/portraits/demo${(Math.floor(Math.random() * 6) + 1)}.jpeg`,
            isPrimary: true,
            remoteUrl: null,
            uploadStatus: 'local',
          },
        ],
        bio: user.bio,
        interests: user.interests,
        languages: user.languages,
        location: user.location,
        occupation: user.occupation,
        verification_status: user.verification,
        availability_status: user.availability,
        latitude: user.lat,
        longitude: user.lng,
        created_at: user.created_at,
        social_links: [],
      });

      if (profileRes.status !== 201 && profileRes.status !== 200) {
        console.error(`Failed to create profile for ${user.email}:`, profileRes.status, profileRes.body);
        continue;
      }

      console.log(`Created profile for: ${user.displayName}\n`);
    } catch (err) {
      console.error(`Error creating profile for ${user.email}:`, err.message);
    }
  }

  console.log('Demo user seeding complete.');
}

createDemoUsers().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
