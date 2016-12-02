#pragma once

#include "drape_frontend/traffic_generator.hpp"
#include "drape_frontend/tile_utils.hpp"

#include "drape/gpu_program_manager.hpp"
#include "drape/pointers.hpp"
#include "drape/uniform_values_storage.hpp"

#include "geometry/screenbase.hpp"
#include "geometry/spline.hpp"

#include "std/vector.hpp"

namespace df
{

class TrafficRenderer final
{
public:
  TrafficRenderer() = default;

  void AddRenderData(ref_ptr<dp::GpuProgramManager> mng,
                     TrafficRenderData && renderData);

  void SetTexCoords(TrafficTexCoords && texCoords);

  void UpdateTraffic(TrafficSegmentsColoring const & trafficColoring);

  void RenderTraffic(ScreenBase const & screen, int zoomLevel, float opacity,
                     ref_ptr<dp::GpuProgramManager> mng,
                     dp::UniformValuesStorage const & commonUniforms);

  bool HasRenderData() const { return !m_renderData.empty(); }

  void ClearGLDependentResources();
  void Clear(MwmSet::MwmId const & mwmId);

  void OnUpdateViewport(CoverageResult const & coverage, int currentZoomLevel,
                        buffer_vector<TileKey, 8> const & tilesToDelete);
  void OnGeometryReady(int currentZoomLevel);

  static float GetPixelWidth(RoadClass const & roadClass, int zoomLevel);

private:
  vector<TrafficRenderData> m_renderData;
  TrafficTexCoords m_texCoords;
};

} // namespace df
