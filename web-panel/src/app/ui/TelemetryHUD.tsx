import { EConnectionStatus } from '@/remote-session/remote-session.reducer';
import { cn } from '@/shared/lib/ui';
import type { TelemetryPayload } from '../../../protocol/messages';

type TelemetryHUDProps = {
    status: EConnectionStatus;
    latencyMs: number | null;
    telemetry: TelemetryPayload | null;
};

export const TelemetryHUD = ({ status, latencyMs, telemetry }: TelemetryHUDProps) => {
    const isConnected = status === EConnectionStatus.Connected;
    const cpu = telemetry?.cpuPercent ?? 0;
    const ram = telemetry?.memoryUsedMb ?? 0;

    return (
        <aside
            aria-label="Hardware & Telemetry HUD"
            className="mb-2.5 rounded-lg border border-[#163252]/60 bg-[#070a13]/85 p-2.5 font-mono text-xs shadow-[0_4px_20px_-4px_rgba(0,240,255,0.08)] backdrop-blur-md pointer-coarse:backdrop-blur-none"
        >
            <div className="flex items-center justify-between border-b border-[#163252]/40 pb-1.5">
                <div className="flex items-center gap-1.5">
                    <span
                        className={cn(
                            'size-2 rounded-full shadow-[0_0_8px_currentColor]',
                            isConnected
                                ? 'bg-[#00f0ff] text-[#00f0ff] motion-safe:animate-pulse'
                                : 'bg-amber-400 text-amber-400',
                        )}
                    />
                    <span className="text-[10px] font-bold tracking-wider text-[#38bdf8]">
                        SOVEREIGN TITAN HUD
                    </span>
                </div>
                <div className="text-[9px] font-medium tracking-wide text-slate-400">
                    @abdelrahmanayman722-ops
                </div>
            </div>

            <div className="mt-2 grid grid-cols-3 gap-2 text-[10.5px]">
                {/* Ping / Latency */}
                <div className="flex flex-col rounded bg-[#0d1527]/70 p-1.5">
                    <span className="text-[8.5px] uppercase tracking-wider text-slate-400">
                        PING
                    </span>
                    <span
                        className={cn(
                            'font-bold',
                            latencyMs == null
                                ? 'text-slate-400'
                                : latencyMs < 60
                                  ? 'text-[#00f0ff]'
                                  : latencyMs < 150
                                    ? 'text-emerald-400'
                                    : 'text-amber-400',
                        )}
                    >
                        {latencyMs != null ? `${latencyMs}ms` : isConnected ? '<10ms' : '--'}
                    </span>
                </div>

                {/* CPU Usage */}
                <div className="flex flex-col rounded bg-[#0d1527]/70 p-1.5">
                    <div className="flex items-center justify-between text-[8.5px] uppercase tracking-wider text-slate-400">
                        <span>CPU</span>
                        <span>{cpu}%</span>
                    </div>
                    <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-slate-800">
                        <div
                            className={cn(
                                'h-full transition-all duration-500',
                                cpu > 80
                                    ? 'bg-rose-500 shadow-[0_0_6px_#f43f5e]'
                                    : cpu > 50
                                      ? 'bg-amber-400 shadow-[0_0_6px_#facc15]'
                                      : 'bg-[#00f0ff] shadow-[0_0_6px_#00f0ff]',
                            )}
                            style={{ width: `${Math.max(5, Math.min(100, cpu))}%` }}
                        />
                    </div>
                </div>

                {/* RAM Usage */}
                <div className="flex flex-col rounded bg-[#0d1527]/70 p-1.5">
                    <span className="text-[8.5px] uppercase tracking-wider text-slate-400">
                        RAM
                    </span>
                    <span className="font-bold text-[#38bdf8]">
                        {ram > 0 ? `${ram} MB` : isConnected ? 'Active' : '--'}
                    </span>
                </div>
            </div>
        </aside>
    );
};
