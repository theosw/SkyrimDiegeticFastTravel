type RingDesign = "thin" | "norden";

type SelectionRingVectorProps = {
  design: RingDesign;
  bodyThickness: number;
  separateFeathers: boolean;
  featherThickness: number;
  featherRotation: number;
  featherRootOverlap: number;
};

type SourcePoint = { x: number; y: number };
type SourceRect = { x: number; y: number; width: number; height: number };
type FeatherSide = "left" | "right" | "top" | "bottom";

type SourcePath = {
  className: "vector-shadow" | "vector-layer-light" | "vector-layer-dark";
  d: string;
};

type SourceArrow = {
  paths: SourcePath[];
  arrowheadPath: SourcePath;
  feather: {
    side: FeatherSide;
    bodyCut: number;
    featherEdge: number;
    pivot: SourcePoint;
  };
};

type SourceDesign = {
  viewBox: string;
  canvas: { x: number; y: number; width: number; height: number };
  center: SourcePoint;
  ringRadius: number;
  outerRadius: number;
  baselineThickness: number;
  arrows: SourceArrow[];
};

const THIN_LIGHT_PATH = "m 92,196 c .560223,-6.95441 5.984468,-11.27677 7.332195,-18.55252 2.539765,-6.09089 7.479845,-10.71028 9.965455,-17.34304 C 111.44462,152.33583 121.46292,148.2543 121,140 c -5.04425,-4.88354 -11.28322,-8.59553 -16.01896,-12.69195 .69312,-3.88367 12.42402,-4.02896 17.37476,-6.47062 C 137.57053,116.55829 152.78527,112.27914 168,108 c -3.66667,21.33333 -7.33333,42.66667 -11,64 -6.49309,-5.36684 -12.11175,-12.93304 -19.12165,-17 -5.87247,2.17906 -8.50027,10.72993 -13.09359,15.42096 -7.82997,10.34157 -12.32489,22.92168 -17.28462,34.76593 -3.21707,16.09115 -9.162369,31.87446 -7.50014,48.51614 -.643752,9.35967 .34406,18.50084 3,27.41862 -.002,12.42853 6.9483,23.72872 9.93147,35.67276 2.69707,4.48793 6.95147,10.43005 9.03771,16.45674 3.48908,5.16477 8.15434,10.13164 11.16447,16.16269 C 137.73699,357.31636 145.1024,363.09343 151,370 c 5.83905,1.96712 8.87077,9.05326 14.88904,10.68388 11.73145,10.80632 26.94075,16.08282 41.19567,22.60157 17.11075,5.7159 35.14568,6.50853 52.91529,8.71455 1.81411,11.10072 8.4939,21.21452 12.23706,31.92396 2.90446,9.09631 9.39541,17.46515 9.76294,27.07604 -3.48542,7.014 -13.08683,4.24116 -13.509,-3.2252 C 266.65853,458.35732 259.07281,451.58472 258,442 c -4.81662,-4.25977 -3.11989,-13.96386 -10.46971,-13.38867 -5.15536,.84335 -17.47695,-4.17673 -17.89731,.54081 2.43032,12.40292 8.97749,23.43875 13.36702,34.96951 .14763,6.29858 -13.83581,5.74204 -12.55319,-1.4408 -2.45836,-7.92848 -7.71822,-14.96213 -9.59656,-23.30015 -3.42798,-5.21987 -2.234,-15.88485 -9.16091,-16.98264 C 205.11117,420.98115 199.39901,419.76899 194,416 c -12.92716,-2.47415 -23.29551,-11.42912 -35,-17 -4.74942,-4.85168 -10.29382,-8.94581 -15.10206,-12.62757 -5.09826,-3.56706 -10.27562,-8.39615 -15.00166,-13.47615 C 126.53846,366.78211 120.58066,365.37938 119,359 113.53613,355.792 113.0814,349.40083 108.35021,344.74192 101.26076,334.47981 97.123756,322.17091 91.714549,310.91529 88.805535,297.07208 83.022142,283.60074 82,269.51342 81.952019,251.94177 81.145855,234.30737 85.319152,217.08509 86.372773,209.77186 89.848811,203.03536 92,196 Z";

const THIN_DARK_PATH = "m 405,206 c -2.92477,-15.38144 -12.07814,-28.23852 -19,-42 -4.40416,-4.04926 -8.40841,-9.22368 -12,-14.12165 -6.7366,-7.99576 -15.92092,-15.23588 -23.9618,-22.45543 -13.37862,-8.25418 -26.65083,-16.73095 -41.94067,-20.98716 C 294.64314,100.76147 279.85434,98.805101 265.39177,98 259.49574,96.439699 248.86614,101.82475 247.35947,93.824108 240.57298,76.549405 233.78649,59.274703 227,42 228.31663,35.204125 238.50848,33.150878 240.74107,40.117349 245.02269,54.3521 251.43512,67.707508 258,81 c 7.66667,.333333 15.33333,.666667 23,1 .97017,-6.73779 -6.33402,-11.275122 -5.45554,-18.024972 C 273.2422,56.938242 267.72477,50.583765 268,43 c 4.42845,-6.066339 13.87033,-2.161048 13.97284,5.266948 C 286.98189,60.511298 291.99095,72.755649 297,85 c 7.27615,.215172 12.89298,3.346989 19.44078,5.360195 C 328.84446,93.183938 339.41004,100.97655 351,106 c 4.20981,5.73853 11.27423,6.83957 14.92158,11.66948 5.75329,3.75328 9.7609,7.7298 14.56586,12.3459 12.10416,12.55694 22.26438,26.9827 30.82674,42.08232 3.96344,10.76912 10.17311,21.08147 12.68582,32.14559 1.33273,10.41315 6.61962,20.19677 6.29161,31.02702 1.33153,15.54269 -.82052,31.2846 -1.5731,46.81544 -3.19551,10.33079 -4.3054,21.93942 -9.71851,31.0359 -2.04238,5.2013 -3.66646,12.11201 -7.4309,17.668 -5.4751,8.47346 -9.5034,18.30888 -16.72326,25.13396 -2.20532,6.51028 -11.65351,9.7847 -2.6542,14.80229 5.73939,4.58458 8.60727,6.76426 13.93001,11.2741 2.81446,4.60987 -10.61939,3.2705 -14.4753,7.31402 -10.16603,.52534 -19.2025,6.74016 -29.50077,7.87585 -7.37689,.0167 -12.97631,6.14447 -20.14558,5.81013 5.11998,-15.47033 5.62457,-32.21286 8.85767,-48.20329 1.73597,-6.23037 .95103,-15.41337 4.26398,-19.79671 4.47267,4.73072 9.75843,7.68107 14.04861,12.90887 5.71563,7.23171 11.37814,-.4636 14.23506,-6.11651 3.72469,-5.59681 8.85072,-11.58858 10.59791,-17.29398 5.3856,-5.19663 4.51055,-13.51122 9.35452,-19.34234 1.27624,-5.77764 3.07499,-10.90895 4.64225,-16.39933 -.0459,-6.78085 4.73141,-12.58649 3.57771,-19.71126 2.14979,-19.54636 1.55087,-39.56774 -5.1998,-58.22278 C 405.9186,209.21511 405.4593,207.60756 405,206 Z";

const THIN_LIGHT_ARROWHEAD = "M 121,140 C 115.95575,135.11646 109.71678,131.40447 104.98104,127.30805 C 105.67416,123.42438 117.40506,123.27909 122.3558,120.83743 C 137.57053,116.55829 152.78527,112.27914 168,108 C 164.33333,129.33333 160.66667,150.66667 157,172 C 150.50691,166.63316 144.88825,159.06696 137.87835,155 Z";
const THIN_DARK_ARROWHEAD = "M 392.19164,370.7259 C 397.93103,375.31048 400.79891,377.49016 406.12165,382 C 408.93611,386.60987 395.50226,385.2705 391.64635,389.31402 C 381.48032,389.83936 372.44385,396.05418 362.14558,397.18987 C 354.76869,397.20657 349.16927,403.33434 342,403 C 347.11998,387.52967 347.62457,370.78714 350.85767,354.79671 C 352.59364,348.56634 351.8087,339.38334 355.12165,335 C 359.59432,339.73072 364.88008,342.68107 369.17026,347.90887 Z";

const NORDEN_LOWER_SHADOW = "m 188.4,144.85 c .40558,-1.68191 -.16366,-2.25163 -1.79814,-1.60598 -4.73145,.79233 -9.31467,1.39248 -14.05186,2.15598 .87926,5.10934 -.10664,10.59668 -2.55,15 -2.29882,4.59945 -6.14506,8.2845 -10.7,10.4 -1.1787,.62041 -2.55855,1.03747 -3.85,1.5 -.2455,.60213 -1.33108,.45129 -1.90793,.6 -3.66039,.91976 -7.77118,.71139 -11.19207,-.1 -2.88164,-.70931 -5.46215,-1.82031 -7.95,-3.35 1.13333,-1.38333 2.26667,-2.76667 3.4,-4.15 -5.05,-.4 -10.1,-.8 -15.15,-1.2 1.38333,4.85 2.76667,9.7 4.15,14.55 1,-1.21667 2,-2.43333 3,-3.65 3.0619,1.99358 6.65528,3.84478 9.9,4.55 5.04724,1.45032 10.65262,1.44328 15.75,.35 4.43445,-.97525 8.68769,-3.21167 12.4,-5.95 2.05792,-1.62338 4.20162,-3.85097 5.6,-5.55 1.47696,-2.06048 2.87522,-4.31569 3.75,-6.65 .64225,-.5355 .88504,-2.03815 1.275,-2.95 .12365,-1.80519 2.1346,-1.9758 3.38627,-2.81631 1.77958,-.91123 3.55915,-1.82246 5.33873,-2.73369 -.0702,-.92961 1.21547,-3.56326 -.51321,-2.4087 -2.3456,.9529 -4.69119,1.9058 -7.03679,2.8587 .20173,-1.29897 .27421,-2.68473 .3,-4.05 2.81667,-1.6 5.63333,-3.2 8.45,-4.8 z";
const NORDEN_UPPER_SHADOW = "m 166.25,121.85 c -3.7664,-2.63118 -7.82477,-4.21074 -12.1,-5.1 -4.40776,-.78639 -9.10774,-.59812 -13.4,.4 -3.10533,.90168 -6.78683,2.38 -9.75,4.3 -2.96752,1.84888 -5.67101,4.51607 -7.8,7.05 -1.70322,2.33638 -3.48358,5.21059 -4.4,7.75 -.37107,1.15559 -.88004,2.33565 -1.15,3.5 -2.78333,1.41667 -5.56667,2.83333 -8.35,4.25 .0676,.91591 -1.21793,3.5273 .51321,2.3587 2.3456,-.9529 4.69119,-1.9058 7.03679,-2.8587 -.33527,1.34172 -.24148,2.72593 -.25,4.1 -2.76667,1.66667 -5.53333,3.33333 -8.3,5 -.44751,1.67967 .10226,2.2522 1.7484,1.6076 4.76528,-.79453 9.38163,-1.39514 14.1516,-2.1576 -.74259,-4.50612 -.0921,-9.50149 1.75,-13.5 1.10665,-2.53811 2.88326,-5.41961 5.1,-7.55 2.36232,-2.4124 5.93748,-4.62403 8.85,-5.55 .50814,-.48998 2.66639,-.34169 2.1,-1 2.44828,-.71996 5.46585,-.89407 8.13437,-.67187 3.24255,.23956 6.40309,1.13621 9.36563,2.52187 2.29963,.60324 3.12669,1.74583 1.15047,3.21928 -.3212,.79209 -2.88903,2.54551 -1.12113,2.44367 4.77355,.36235 9.54711,.7247 14.32066,1.08705 -1.4,-4.85 -2.8,-9.7 -4.2,-14.55 -1.13333,1.11667 -2.26667,2.23333 -3.4,3.35 z";
const NORDEN_LOWER_LIGHT = "m 187.8,143.65 c .44746,-1.67999 -.10223,-2.252 -1.74814,-1.60598 -4.68947,.82611 -9.55337,1.35048 -14.05186,2.20598 .73362,4.94621 -.0562,10.36735 -2.45,14.7 -.69382,2.07225 -2.21267,3.88263 -3.65,5.55 -1.61527,1.70589 -3.84448,3.52019 -5.90794,4.62897 -1.77513,.8635 -3.57009,1.82898 -5.49206,2.17103 .0237,.46151 -1.19154,.25319 -1.45,.5 -4.52373,.96244 -9.30076,.70371 -13.53631,-.82877 -1.99148,-.72649 -3.78347,-1.5184 -5.56369,-2.67123 1.13333,-1.38333 2.26667,-2.76667 3.4,-4.15 -5.05,-.4 -10.1,-.8 -15.15,-1.2 1.38333,4.85 2.76667,9.7 4.15,14.55 1,-1.2 2,-2.4 3,-3.6 3.84823,2.57665 8.01767,4.53542 12.55,5.15 2.93175,.60281 6.04317,.4235 9,.3 2.82823,-.35257 5.33435,-.86641 7.85,-1.95 5.43817,-1.94021 10.39397,-5.76327 13.85,-10.1 1.32638,-1.78723 2.77321,-3.99852 3.59299,-6.08598 .13618,-.54028 .65634,-.19361 .65701,-.86402 .57831,-1.14802 1.04032,-2.61401 1.45,-4.1 2.76667,-1.4 5.53333,-2.8 8.3,-4.2 -.035,-.92827 1.3325,-3.55407 -.41405,-2.41079 -2.36199,.9536 -4.72397,1.90719 -7.08595,2.86079 .23323,-1.35017 .209,-2.72584 .2,-4.1 2.83333,-1.58333 5.66667,-3.16667 8.5,-4.75 z";
const NORDEN_UPPER_DARK = "m 165.45,120.9 c -3.27309,-2.28898 -7.03818,-3.87675 -10.6,-4.75 -5.0843,-1.25777 -10.53481,-1.0118 -15.6,.2 -3.94541,1.16999 -8.28603,3.25901 -11.7,6 -4.07362,3.25852 -7.38211,7.72254 -9.3,12.4 -.49494,1.25215 -.99158,2.76048 -1.4,4.05 -2.75,1.4 -5.5,2.8 -8.25,4.2 .0678,.91641 -1.21853,3.52581 .51405,2.36079 2.36199,-.9536 4.72397,-1.90719 7.08595,-2.86079 -.32206,1.30022 -.21689,2.69837 -.3,4.05 -2.76667,1.66667 -5.53333,3.33333 -8.3,5 -.40558,1.68191 .16366,2.25163 1.79814,1.60598 4.74725,-.79622 9.34722,-1.39604 14.10186,-2.15598 -.69958,-4.21126 -.14759,-8.82774 1.45,-12.75 .56456,-1.4401 1.34979,-2.77206 2.1,-4.15 1.97112,-3.07761 4.60329,-5.66327 7.8,-7.6 2.76805,-1.75059 5.88761,-2.76239 9.00625,-3.20625 6.22349,-1.0883 12.64814,.44274 17.99375,3.65625 -1.11696,1.35008 -2.81139,2.59159 -4.15,3.9 5.05,.4 10.1,.8 15.15,1.2 -1.4,-4.85 -2.8,-9.7 -4.2,-14.55 -1.06667,1.13333 -2.13333,2.26667 -3.2,3.4 z";

const NORDEN_LOWER_ARROWHEAD = "M 133.95,168.3 C 135.08333,166.91667 136.21667,165.53333 137.35,164.15 C 132.3,163.75 127.25,163.35 122.2,162.95 C 123.58333,167.8 124.96667,172.65 126.35,177.5 C 127.35,176.3 128.35,175.1 129.35,173.9 Z";
const NORDEN_UPPER_ARROWHEAD = "M 161.85,126.95 C 160.73304,128.30008 159.03861,129.54159 157.7,130.85 C 162.75,131.25 167.8,131.65 172.85,132.05 C 171.45,127.2 170.05,122.35 168.65,117.5 C 167.58333,118.63333 166.51667,119.76667 165.45,120.9 Z";

const DESIGNS: Record<RingDesign, SourceDesign> = {
  thin: {
    viewBox: "0 0 512 512",
    canvas: { x: 0, y: 0, width: 512, height: 512 },
    center: { x: 256, y: 256 },
    ringRadius: 165,
    outerRadius: 178,
    baselineThickness: 2.8,
    arrows: [
      {
        paths: [{ className: "vector-layer-light", d: THIN_LIGHT_PATH }],
        arrowheadPath: { className: "vector-layer-light", d: THIN_LIGHT_ARROWHEAD },
        feather: { side: "bottom", bodyCut: 442, featherEdge: 436, pivot: { x: 256, y: 430 } },
      },
      {
        paths: [{ className: "vector-layer-dark", d: THIN_DARK_PATH }],
        arrowheadPath: { className: "vector-layer-dark", d: THIN_DARK_ARROWHEAD },
        feather: { side: "top", bodyCut: 70, featherEdge: 76, pivot: { x: 256, y: 82 } },
      },
    ],
  },
  norden: {
    viewBox: "98 98 100 100",
    canvas: { x: 98, y: 98, width: 100, height: 100 },
    center: { x: 148, y: 148 },
    ringRadius: 31,
    outerRadius: 33,
    baselineThickness: 6.4,
    arrows: [
      {
        paths: [
          { className: "vector-shadow", d: NORDEN_UPPER_SHADOW },
          { className: "vector-layer-dark", d: NORDEN_UPPER_DARK },
        ],
        arrowheadPath: { className: "vector-layer-dark", d: NORDEN_UPPER_ARROWHEAD },
        feather: { side: "left", bodyCut: 113, featherEdge: 119, pivot: { x: 120, y: 145 } },
      },
      {
        paths: [
          { className: "vector-shadow", d: NORDEN_LOWER_SHADOW },
          { className: "vector-layer-light", d: NORDEN_LOWER_LIGHT },
        ],
        arrowheadPath: { className: "vector-layer-light", d: NORDEN_LOWER_ARROWHEAD },
        feather: { side: "right", bodyCut: 187, featherEdge: 180, pivot: { x: 176, y: 151 } },
      },
    ],
  },
};

function SourcePaths({ paths, omitShadow = false }: { paths: SourcePath[]; omitShadow?: boolean }) {
  return paths
    .filter((path) => !omitShadow || path.className !== "vector-shadow")
    .map((path, index) => <path className={path.className} d={path.d} fillRule="evenodd" key={`${path.className}-${index}`} />);
}

function cutRect(canvas: SourceRect, side: FeatherSide, boundary: number): SourceRect {
  const right = canvas.x + canvas.width;
  const bottom = canvas.y + canvas.height;
  if (side === "left") return { x: canvas.x, y: canvas.y, width: boundary - canvas.x, height: canvas.height };
  if (side === "right") return { x: boundary, y: canvas.y, width: right - boundary, height: canvas.height };
  if (side === "top") return { x: canvas.x, y: canvas.y, width: canvas.width, height: boundary - canvas.y };
  return { x: canvas.x, y: boundary, width: canvas.width, height: bottom - boundary };
}

function featherRect(canvas: SourceRect, side: FeatherSide, edge: number, overlap: number): SourceRect {
  const adjustedEdge = edge + (side === "left" || side === "top" ? overlap : -overlap);
  return cutRect(canvas, side, adjustedEdge);
}

function radialScale(thickness: number, source: SourceDesign) {
  const radialShift = (thickness - source.baselineThickness) * source.canvas.width / 100;
  return Math.max(0.55, 1 - radialShift / source.ringRadius);
}

function radialInnerRadius(thickness: number, source: SourceDesign) {
  const requestedWidth = thickness * source.canvas.width / 100;
  return Math.max(0, source.outerRadius - requestedWidth);
}

function scaleAround(center: SourcePoint, scale: number) {
  return `translate(${center.x} ${center.y}) scale(${scale}) translate(${-center.x} ${-center.y})`;
}

function RadialWeightedPaths({
  paths,
  source,
  thickness,
  maskId,
  forceOmitShadow = false,
}: {
  paths: SourcePath[];
  source: SourceDesign;
  thickness: number;
  maskId: string;
  forceOmitShadow?: boolean;
}) {
  const delta = thickness - source.baselineThickness;
  const edited = Math.abs(delta) > 0.001;
  const omitShadow = forceOmitShadow || edited;
  if (!edited) return <SourcePaths omitShadow={omitShadow} paths={paths} />;

  if (delta < 0) {
    return (
      <g mask={`url(#${maskId})`}>
        <SourcePaths omitShadow paths={paths} />
      </g>
    );
  }

  const targetScale = radialScale(thickness, source);
  const sweepSteps = 12;
  return Array.from({ length: sweepSteps + 1 }, (_, index) => {
    const scale = 1 + (targetScale - 1) * index / sweepSteps;
    return (
      <g transform={scaleAround(source.center, scale)} key={index}>
        <SourcePaths omitShadow paths={paths} />
      </g>
    );
  });
}

export default function SelectionRingVector({
  design,
  bodyThickness,
  separateFeathers,
  featherThickness,
  featherRotation,
  featherRootOverlap,
}: SelectionRingVectorProps) {
  const source = DESIGNS[design];
  const bodyDelta = bodyThickness - source.baselineThickness;
  const featherDelta = featherThickness - source.baselineThickness;
  const splitFeathers = separateFeathers && (Math.abs(bodyThickness - featherThickness) > 0.001 || Math.abs(featherRotation) > 0.001);
  const overlap = featherRootOverlap * source.canvas.width / 100;

  return (
    <svg className={`procedural-ring-svg source-matched-vector ${design}-vector`} viewBox={source.viewBox} role="presentation" aria-hidden="true">
      {(Math.abs(bodyDelta) > 0.001 || splitFeathers) && (
        <defs>
          {source.arrows.map((arrow, index) => {
            const bodyCut = cutRect(source.canvas, arrow.feather.side, arrow.feather.bodyCut);
            const featherClip = featherRect(source.canvas, arrow.feather.side, arrow.feather.featherEdge, overlap);
            const bodyInnerRadius = radialInnerRadius(bodyThickness, source);
            const featherInnerRadius = radialInnerRadius(featherThickness, source);
            return (
              <g key={index}>
                {bodyDelta < -0.001 && (
                  <mask id={`${design}-body-radial-weight-${index}`} maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse" x={source.canvas.x} y={source.canvas.y} width={source.canvas.width} height={source.canvas.height}>
                    <rect {...source.canvas} fill="white" />
                    <circle cx={source.center.x} cy={source.center.y} r={bodyInnerRadius} fill="black" />
                  </mask>
                )}
                {splitFeathers && featherDelta < -0.001 && (
                  <mask id={`${design}-feather-radial-weight-${index}`} maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse" x={source.canvas.x} y={source.canvas.y} width={source.canvas.width} height={source.canvas.height}>
                    <rect {...source.canvas} fill="white" />
                    <circle cx={source.center.x} cy={source.center.y} r={featherInnerRadius} fill="black" />
                  </mask>
                )}
                {splitFeathers && (
                  <>
                    <mask id={`${design}-body-without-feather-${index}`} maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse" x={source.canvas.x} y={source.canvas.y} width={source.canvas.width} height={source.canvas.height}>
                      <rect {...source.canvas} fill="white" />
                      <rect {...bodyCut} fill="black" />
                    </mask>
                    <clipPath id={`${design}-feather-region-${index}`} clipPathUnits="userSpaceOnUse">
                      <rect {...featherClip} />
                    </clipPath>
                  </>
                )}
              </g>
            );
          })}
        </defs>
      )}

      {source.arrows.map((arrow, index) => {
        if (!splitFeathers) {
          return (
            <g key={index}>
              <RadialWeightedPaths
                maskId={`${design}-body-radial-weight-${index}`}
                paths={arrow.paths}
                source={source}
                thickness={bodyThickness}
              />
              {bodyDelta < -0.001 && <SourcePaths omitShadow paths={[arrow.arrowheadPath]} />}
            </g>
          );
        }

        const { pivot } = arrow.feather;
        return (
          <g key={index}>
            <g mask={`url(#${design}-body-without-feather-${index})`}>
              <RadialWeightedPaths
                maskId={`${design}-body-radial-weight-${index}`}
                forceOmitShadow
                paths={arrow.paths}
                source={source}
                thickness={bodyThickness}
              />
            </g>
            {bodyDelta < -0.001 && <SourcePaths omitShadow paths={[arrow.arrowheadPath]} />}
            <g transform={`rotate(${featherRotation} ${pivot.x} ${pivot.y})`}>
              <g clipPath={`url(#${design}-feather-region-${index})`}>
                <RadialWeightedPaths
                  maskId={`${design}-feather-radial-weight-${index}`}
                  forceOmitShadow
                  paths={arrow.paths}
                  source={source}
                  thickness={featherThickness}
                />
              </g>
            </g>
          </g>
        );
      })}
    </svg>
  );
}
