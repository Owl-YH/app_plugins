import 'package:flutter/widgets.dart';
import 'package:spatial_confetti/spatial_confetti.dart';

/// 使用指南的可复制配方；属于文档示例，不扩充插件的公开 API。
abstract final class GuidePresets {
  /// 少量纸片和短彩带，用于按钮成功反馈。
  static ConfettiEffect celebration(Vec3 origin) => ConfettiEffect(
    seed: 17,
    emitters: [
      ConfettiEmitter.burst(
        origin: origin,
        direction: const Vec3(0, -1, 0),
        speed: const NumberRange(7, 10),
        spread: .65,
        radius: .04,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(milliseconds: 2400), Duration(milliseconds: 3400)),
        ),
        delay: Duration.zero,
        burstCount: 48,
        particles: [
          ParticleChoice(
            weight: 1,
            colors: const [
              Color(0xfffb7185),
              Color(0xfffbbf24),
              Color(0xff38bdf8),
              Color(0xffa78bfa),
            ],
            particle: const PaperParticle.noBend(
              size: PaperSize.stretched(
                width: NumberRange(.035, .065),
                height: NumberRange(.045, .085),
              ),
              massPerArea: .16,
              dragCoefficient: .35,
              angularSpeed: NumberRange(-7, 7),
            ),
          ),
        ],
      ),
      ConfettiEmitter.burst(
        origin: origin,
        direction: const Vec3(0, -1, 0),
        speed: const NumberRange(7, 9),
        spread: .55,
        radius: .02,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(milliseconds: 2500), Duration(milliseconds: 3500)),
        ),
        delay: const Duration(milliseconds: 40),
        burstCount: 4,
        particles: [
          ParticleChoice(
            weight: 1,
            colors: const [Color(0xfffbbf24), Color(0xff38bdf8), Color(0xfffb7185)],
            particle: const RibbonParticle(
              width: NumberRange(.025, .04),
              length: NumberRange(.3, .5),
              segments: 10,
              massPerArea: .12,
              dragCoefficient: .6,
              surfaceFriction: .015,
              bendingStiffness: .000002,
              inPlaneBendingStiffness: .0002,
              torsionalStiffness: .000001,
              thickness: .00005,
              damping: 1.5,
              angularSpeed: NumberRange(-2, 2),
            ),
          ),
        ],
      ),
    ],
  );

  /// 左右下方朝内发射，延迟形成错落的两股纸片。
  static ConfettiEffect sideCannons({required Vec3 left, required Vec3 right}) => ConfettiEffect(
    seed: 41,
    emitters: [
      ConfettiEmitter.burst(
        origin: left,
        direction: const Vec3(.8, -1, .08),
        speed: const NumberRange(8, 12),
        spread: .35,
        radius: .03,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(seconds: 3), Duration(seconds: 4)),
        ),
        delay: Duration.zero,
        burstCount: 60,
        particles: [
          ParticleChoice(
            weight: 1,
            colors: const [Color(0xfffbbf24), Color(0xfffb7185), Color(0xfffda4af)],
            particle: const PaperParticle.noBend(
              size: PaperSize.stretched(
                width: NumberRange(.035, .07),
                height: NumberRange(.055, .1),
              ),
              massPerArea: .16,
              dragCoefficient: .35,
              angularSpeed: NumberRange(-9, 9),
            ),
          ),
        ],
      ),
      ConfettiEmitter.burst(
        origin: right,
        direction: const Vec3(-.8, -1, -.08),
        speed: const NumberRange(8, 12),
        spread: .35,
        radius: .03,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(seconds: 3), Duration(seconds: 4)),
        ),
        delay: const Duration(milliseconds: 120),
        burstCount: 60,
        particles: [
          ParticleChoice(
            weight: 1,
            colors: const [Color(0xff38bdf8), Color(0xffa78bfa), Color(0xff2dd4bf)],
            particle: const PaperParticle.noBend(
              size: PaperSize.stretched(
                width: NumberRange(.035, .07),
                height: NumberRange(.055, .1),
              ),
              massPerArea: .16,
              dragCoefficient: .35,
              angularSpeed: NumberRange(-9, 9),
            ),
          ),
        ],
      ),
    ],
  );

  /// 六个顶端发射点铺成一排；不用球形 radius 冒充水平分布。
  static ConfettiEffect paperRain({required double halfWidth, required double top}) =>
      ConfettiEffect(
        seed: 73,
        emitters: [
          for (var column = 0; column < 6; column++)
            ConfettiEmitter.stream(
              origin: Vec3(-halfWidth + 2 * halfWidth * (column + .5) / 6, top, 0),
              direction: const Vec3(0, 1, 0),
              speed: const NumberRange(.3, 1),
              spread: .35,
              radius: .1,
              lifetime: const ParticleLifetime(
                duration: DurationRange(Duration(seconds: 3), Duration(milliseconds: 4500)),
              ),
              delay: Duration(milliseconds: column * 40),
              burstCount: 0,
              rate: 7,
              duration: const Duration(milliseconds: 2500),
              particles: [
                ParticleChoice(
                  weight: 1,
                  colors: const [
                    Color(0xfffbbf24),
                    Color(0xff38bdf8),
                    Color(0xfffb7185),
                    Color(0xffa78bfa),
                    Color(0xff2dd4bf),
                  ],
                  particle: const PaperParticle.noBend(
                    size: PaperSize.stretched(
                      width: NumberRange(.035, .07),
                      height: NumberRange(.045, .09),
                    ),
                    massPerArea: .08,
                    dragCoefficient: 1.15,
                    angularSpeed: NumberRange(-4, 4),
                  ),
                ),
              ],
            ),
        ],
      );

  /// 少量长彩带，配合外部 XYZ 风场观察材料弯曲与扭转。
  static ConfettiEffect ribbonDance(Vec3 origin) => ConfettiEffect(
    seed: 29,
    emitters: [
      ConfettiEmitter.burst(
        origin: origin,
        direction: const Vec3(0, -1, 0),
        speed: const NumberRange(7, 9),
        spread: .4,
        radius: .12,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(milliseconds: 3500), Duration(milliseconds: 4500)),
        ),
        delay: Duration.zero,
        burstCount: 5,
        particles: [
          ParticleChoice(
            weight: 1,
            colors: const [
              Color(0xfffb7185),
              Color(0xfffbbf24),
              Color(0xff38bdf8),
              Color(0xffa78bfa),
            ],
            particle: const RibbonParticle(
              width: NumberRange(.035, .055),
              length: NumberRange(.9, 1.4),
              segments: 18,
              massPerArea: .12,
              dragCoefficient: .6,
              surfaceFriction: .012,
              bendingStiffness: .000002,
              inPlaneBendingStiffness: .0002,
              torsionalStiffness: .000001,
              thickness: .00005,
              damping: 1.5,
              angularSpeed: NumberRange(-3, 3),
            ),
          ),
        ],
      ),
    ],
  );

  /// 纸片与独立速度色带组合；开场色带短暂展开收回，纸片继续飞行。
  static ConfettiEffect streakBurst(Vec3 origin) => ConfettiEffect(
    seed: 97,
    emitters: [
      ConfettiEmitter.burst(
        origin: origin,
        direction: const Vec3(0, -1, 0),
        speed: const NumberRange(9, 13),
        spread: .6,
        radius: .06,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(milliseconds: 2500), Duration(milliseconds: 3500)),
        ),
        delay: Duration.zero,
        burstCount: 28,
        particles: [
          ParticleChoice(
            weight: 1,
            colors: const [Color(0xff7dd3fc), Color(0xffc4b5fd), Color(0xfffde68a)],
            particle: const PaperParticle.noBend(
              size: PaperSize.stretched(
                width: NumberRange(.035, .055),
                height: NumberRange(.065, .095),
              ),
              massPerArea: .16,
              dragCoefficient: .3,
              angularSpeed: NumberRange(-2, 2),
            ),
          ),
        ],
      ),
      ConfettiEmitter.burst(
        origin: origin,
        direction: const Vec3(0, -1, .08),
        speed: const NumberRange(22, 30),
        spread: .24,
        burstCount: 7,
        lifetime: const ParticleLifetime(
          duration: DurationRange.fixed(Duration(milliseconds: 260)),
          fadeOut: Duration(milliseconds: 100),
        ),
        particles: [
          ParticleChoice(
            particle: const StreakParticle(),
            colors: const [Color(0xffffc84a), Color(0xffff416c), Color(0xffa65cff)],
          ),
        ],
      ),
    ],
  );

  /// 六种纸片轮廓与丝带共用权重选择；每次出生独立抽取尺寸和颜色。
  static ConfettiEffect shapeMix(Vec3 origin) => ConfettiEffect(
    seed: 61,
    emitters: [
      ConfettiEmitter.burst(
        origin: origin,
        direction: const Vec3(0, -1, .1),
        speed: const NumberRange(7, 10),
        spread: .48,
        burstCount: 56,
        lifetime: const ParticleLifetime(
          duration: DurationRange(Duration(seconds: 3), Duration(seconds: 4)),
        ),
        particles: [
          for (final shape in [
            const PaperShape.rectangle(aspectRatio: .7),
            const PaperShape.circle(),
            const PaperShape.triangle(),
            const PaperShape.star(points: 5, innerRadiusRatio: .45),
            const PaperShape.heart(),
            PaperShape.polygon(
              vertices: const [
                Offset(0, 0),
                Offset(1, 0),
                Offset(.4, .5),
                Offset(1, 1),
                Offset(0, 1),
              ],
            ),
          ])
            ParticleChoice(
              weight: 2,
              particle: PaperParticle.noBend(
                shape: shape,
                size: const PaperSize.proportional(NumberRange(.15, .23)),
                massPerArea: .12,
                dragCoefficient: .65,
                surfaceFriction: .02,
                angularSpeed: const NumberRange(-4, 4),
              ),
            ),
          ParticleChoice(
            weight: 1,
            particle: const RibbonParticle(
              width: NumberRange(.018, .025),
              length: NumberRange(.3, .5),
              segments: 10,
            ),
          ),
        ],
      ),
    ],
  );
}

/// 同一份环境配置供可运行示例与真实素材导出共同使用。
typedef GuideScene = ({
  String id,
  String title,
  ConfettiEffect effect,
  WindField wind,
  ConfettiCamera camera,
  Duration duration,
  Duration posterTime,
});

/// 配方只包含发射器；相机和风场属于宿主，明确在这里组合。
List<GuideScene> guideScenes(Size size) {
  const camera = ConfettiCamera(viewHeight: 6.5, distance: 10, near: .25, far: 60);
  final bottom = camera.unproject(Offset(size.width * .5, size.height * .87), size);
  final left = camera.unproject(Offset(size.width * .07, size.height * .87), size);
  final right = camera.unproject(Offset(size.width * .93, size.height * .87), size);
  final topLeft = camera.unproject(Offset.zero, size);
  return [
    (
      id: 'celebration',
      title: '轻量庆祝',
      effect: GuidePresets.celebration(bottom),
      wind: WindField(),
      camera: camera,
      duration: const Duration(seconds: 4),
      posterTime: const Duration(milliseconds: 500),
    ),
    (
      id: 'side-cannons',
      title: '双侧礼炮',
      effect: GuidePresets.sideCannons(left: left, right: right),
      wind: WindField(
        sources: [WindSource.global(velocity: const Vec3(.3, 0, .15), variation: .15, phase: 0)],
        turbulence: .1,
        spatialScale: .8,
        seed: 1,
      ),
      camera: camera,
      duration: const Duration(milliseconds: 4500),
      posterTime: const Duration(milliseconds: 550),
    ),
    (
      id: 'paper-rain',
      title: '纸片雨',
      effect: GuidePresets.paperRain(halfWidth: -topLeft.x, top: topLeft.y + .12),
      wind: WindField(
        sources: [WindSource.global(velocity: const Vec3(.45, 0, .2), variation: .15, phase: 0)],
        turbulence: .2,
        spatialScale: .8,
        seed: 1,
      ),
      camera: camera,
      duration: const Duration(seconds: 5),
      posterTime: const Duration(milliseconds: 1500),
    ),
    (
      id: 'ribbon-dance',
      title: '长丝带飘舞',
      effect: GuidePresets.ribbonDance(bottom),
      wind: WindField(
        sources: [WindSource.global(velocity: const Vec3(.8, -.15, .45), variation: .2, phase: 0)],
        turbulence: .35,
        spatialScale: .8,
        seed: 8,
      ),
      camera: camera,
      duration: const Duration(seconds: 5),
      posterTime: const Duration(milliseconds: 800),
    ),
    (
      id: 'streak-burst',
      title: '开场速度色带',
      effect: GuidePresets.streakBurst(bottom),
      wind: WindField(),
      camera: camera,
      duration: const Duration(seconds: 4),
      posterTime: const Duration(milliseconds: 125),
    ),
    (
      id: 'shape-mix',
      title: '多形状随机混合',
      effect: GuidePresets.shapeMix(bottom),
      wind: WindField(
        sources: [WindSource.global(velocity: const Vec3(.35, 0, .2), variation: .15)],
        turbulence: .12,
      ),
      camera: camera,
      duration: const Duration(seconds: 5),
      posterTime: const Duration(milliseconds: 550),
    ),
  ];
}
