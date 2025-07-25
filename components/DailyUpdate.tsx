import { useAddFrame, useNotification } from '@coinbase/onchainkit/minikit';
import React, { useState, useEffect } from 'react';
import ReactPlayer from 'react-player';

export default function DailyUpdate({ selected }: { selected: string }) {
  const [videos, setVideos] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');

  useEffect(() => {
    const fetchVideos = async () => {
      try {
        const response = await fetch('https://billcaster.s3.ap-south-1.amazonaws.com/videos/billnews');
        if (!response.ok) {
          throw new Error('Failed to fetch video');
        }
        const videoUrl = response.url;
        setVideos(videoUrl);
      } catch (err) {
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    };

    fetchVideos();
  }, []);

  useEffect(() => {
    if (videos) {
      // No need for manual video element handling with ReactPlayer
    }
  }, [videos]);

  return (
    <div className="max-w-6xl mx-auto p-4 text-white animate-rise">

      {error && (
        <div className="mt-4 p-4 bg-red-800 border border-red-600 rounded-lg">
          <p className="text-red-300">{error}</p>
        </div>
      )}

      {!loading && videos.length > 0 && (
        <div className="grid gap-4 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3 mt-8">

            <div
              className=" w-fit p-3 shadow-xl mx-auto flex flex-col items-center justify-center shadow-red-800/20 transition-shadow rounded-lg overflow-hidden bg-red-800/10 border-x-[2px]  border-red-500/30"
            >
              <h2 className=" text-xl text-white font-poppins font-bold mb-2">Daily Base Report</h2>

              {/* Video Container */}
              {videos && <div className="">
                <ReactPlayer
                  src={videos}
                  controls
                  className={`w-full object-cover rounded-lg duration-200 transition-all ${
                    selected === 'youtube' ? 'border-red-500' : selected === 'twitch' ? 'border-purple-500' : ''
                  }`}
                />
              </div>}

              {/* Video Title Bar */}              
            </div>
  
        </div>
      )}

      {!loading && videos.length === 0 && !error && (
        <div className="text-center py-12">
          <p className="text-gray-400">No videos found.</p>
        </div>
      )}
    </div>
  );
};

