import numpy as np
from tensorflow.keras.models import load_model
from app.entities.agent_data import AgentData
from app.entities.processed_agent_data import ProcessedAgentData

rolling_window = np.zeros((1, 100, 3))
model_path = "./app/model.hdf5"
loaded_model = load_model(model_path)


def process_agent_data(
    agent_data: AgentData,
) -> ProcessedAgentData:
    """
    Process agent data and classify the state of the road surface.
    Parameters:
        agent_data (AgentData): Agent data that containing accelerometer, GPS, and timestamp.
    Returns:
        processed_data_batch (ProcessedAgentData): Processed data containing the classified state of the road surface and agent data.
    """
    global rolling_window, loaded_model
    # Accessing the accelerometer data from the AgentData instance
    x_acceleration = agent_data.accelerometer.x
    y_acceleration = agent_data.accelerometer.y
    z_acceleration = agent_data.accelerometer.z

    new_data_point = np.array([x_acceleration, y_acceleration, z_acceleration])

    # Update the rolling window by adding new_data_point at the end and removing the first element
    rolling_window = np.roll(rolling_window, shift=-1, axis=1)
    rolling_window[:, -1, :] = new_data_point

    # Make predictions on the updated rolling window
    predictions = loaded_model.predict(rolling_window)

    # Decode the predictions if necessary (e.g., if using one-hot encoding for labels during training)
    decoded_predictions = np.argmax(predictions, axis=1)

    # Map the decoded predictions back to your class labels
    class_labels = ["bad_road", "regular_road", "good_road"]
    road_state = [class_labels[i] for i in decoded_predictions][0]

    # if 14000 > z_acceleration < 18000:
    #     road_state = "normal"
    # elif 12000 > z_acceleration < 14000 or 18000 > z_acceleration < 20000:
    #     road_state = "small pits"
    # else:
    #     road_state = "large pits"

    # Create a ProcessedAgentData to store the classified road surface state
    processed_data = ProcessedAgentData(road_state=road_state, agent_data=agent_data)
    return processed_data
